import { ActionType } from "hardhat/types";

const preprocessFile = require("c-preprocessor").compileFile;
const fs = require("fs");
const tmp = require("tmp");
const path = require("path");
const rimraf = require("rimraf");

// Root directory of the project where `hardhat` command is executed
const ROOT_DIR = process.cwd();

// Caching dirs that already exist so that we won't try to make them.
const existingDirs = new Set<string>();

const cleanTmpDir = async (): Promise<boolean> => {
  return new Promise((resolve, reject) => {
    rimraf(path.join(ROOT_DIR, "tmp"), (err: any) => {
      if (err) {
        reject(err);
      }

      resolve(true);
    });
  });
};

const tryMkDir = (name?: string) => {
  if (name && existingDirs.has(name)) return;
  const dirs = name?.split(path.sep);
  const leafDir = dirs?.pop();
  try {
    // Create a tmp directory
    tmp.dirSync({
      tmpdir: ROOT_DIR,
      dir: dirs?.join(path.sep) || "",
      name: leafDir || "tmp",
    });
    existingDirs.add(path.join(dirs?.join(path.sep) || "", leafDir || "tmp"));
  } catch (error) {
    // Directory already exists
    console.error("mkdir failed: ", name);
  }
};

/**
 * Creates a temporary file with a random name.
 * @param fileName path to the original file
 * @returns a promise that resolves to an object containng `fd` the file
 * descriptor and `path` the path to the temporary file.
 */
const createTmpFile = async (
  fileName: string
): Promise<{ fd: number; p: string }> => {
  const name = path.basename(fileName);
  const relativePath = path.relative(ROOT_DIR, path.dirname(fileName));
  const dirs = relativePath.split(path.sep);

  for (let i = 0; i < dirs.length; i++) {
    tryMkDir(path.join("tmp", ...dirs.slice(0, i + 1)));
  }

  return new Promise((resolve, reject) => {
    tmp.file(
      { tmpdir: ROOT_DIR, dir: path.join("tmp", relativePath), name: name },
      function _tempFileCreated(
        err: any,
        p: string,
        fd: number,
        cleanupCallback: Function | undefined
      ) {
        if (err) {
          reject(err);
        }

        resolve({ p, fd });
      }
    );
  });
};

/**
 * Preprocess a Vyper contract that uses C pragmas.
 * @param fileName The Path to the file
 * @returns A promise that would resolve into the preprocessed data
 */
const preprocess = async (fileName: string): Promise<string> => {
  return new Promise((resolve, reject) => {
    preprocessFile(fileName, { basePath: "" }, (err: any, result: any) => {
      if (err) {
        reject(err);
      }

      resolve(result);
    });
  });
};

/**
 * Preprocess the `filename` and save the result into a temporary file.
 * @param fileName The Path to the file for preprocesing
 * @returns a promise that resolves into the `path` to the preprocessed file.
 */
const preprocessAndCreateTmpFile = async (
  fileName: string
): Promise<string> => {
  // Preprocess `fileName`
  const result = await preprocess(fileName);

  // Create a temp file and write the result into.
  let p: string;
  let fd: number;
  try {
    ({ p, fd } = await createTmpFile(fileName));
    fs.write(fd, result, 0, "utf-8", () => {});
  } catch {
    const name = path.basename(fileName);
    const relativePath = path.relative(ROOT_DIR, path.dirname(fileName));

    p = path.join(ROOT_DIR, "tmp", relativePath, name);

    fd = await new Promise((resolve, reject) => {
      fs.open(p, (err: Error, fd: number) => {
        if (err) {
          reject(err);
        }

        resolve(fd);
      });
    });

    fs.write(fd, result, 0, "utf-8", () => {});
  }

  return p;
};

/**
 * A hook to intercept the Vyper compilation, preprocess the contracts and then compile.
 * @param taskArgs arguments passed to this hook
 * @param _ unused Hardhat runtime environment variable.
 * @param runSuper the parent hook.
 * @returns `compiled` a JSON object created by `Vyper` command line.
 */
export const compileHook: ActionType<any> = async (taskArgs, _, runSuper) => {
  // Clean tmp directory
  await cleanTmpDir();

  // Create tmp directory if it does not exist.
  tryMkDir();

  // Temp paths to write preprocessed files to.
  const tmpPaths = await Promise.all(
    taskArgs.inputPaths.map((fileName: string) => {
      return preprocessAndCreateTmpFile(fileName);
    })
  );

  // Save original input paths but filter out interfaces
  const inputPaths = taskArgs.inputPaths.filter(
    (file: string) => !file.match(/interface/i)
  );

  // Replace input paths by temp paths and filter out interfaces
  taskArgs.inputPaths = tmpPaths.filter(
    (file: string) => !file.match(/interface/i)
  );

  // Compile tmp preprocessed Vyper contracts using the parent hook
  const tmpCompiled = await runSuper(taskArgs);

  // Define a new compile object.
  const compiled: { [key: string]: object } = {};

  // Set the Vyper version
  compiled.version = tmpCompiled.version;

  // Replace temp paths with the orginal input paths in the compiled
  // JSON objects.
  inputPaths.forEach((p: string, i: number) => {
    const relativePath = path.relative(ROOT_DIR, p).replaceAll(path.sep, "/");
    const relativeTmpPath = path
      .relative(ROOT_DIR, taskArgs.inputPaths[i])
      .replaceAll(path.sep, "/");

    compiled[relativePath] = tmpCompiled[relativeTmpPath];
  });

  // Clean up temp files.
  tmp.setGracefulCleanup();

  // Return the compiled JSON object.
  return compiled;
};
