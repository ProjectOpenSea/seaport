import { Contract, ContractTransaction } from "ethers";

type DecodedTransactionEvent = {
  eventName: string;
  data: { [key: string | number]: string | number | boolean };
};

type EventDecoder = {
  eventName: string;
  contract: Contract;
};

export async function decodeEvents(
  tx: ContractTransaction,
  eventDecoders: EventDecoder[]
): Promise<DecodedTransactionEvent[]> {
  const receipt = await tx.wait();
  const events = receipt.events;
  if (events == null) {
    return [];
  }

  const decodedEvents = events
    .map((event) => {
      for (const decoder of eventDecoders) {
        try {
          const result = decoder.contract.interface.decodeEventLog(
            decoder.eventName,
            event.data,
            event.topics
          );
          return {
            eventName: decoder.eventName,
            data: result,
          } as DecodedTransactionEvent;
        } catch {}
      }
      return null;
    })
    .filter(Boolean);
  return decodedEvents as DecodedTransactionEvent[];
}
