import type { Contract, ContractTransaction } from "ethers";

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
        // Attempt to decode each event as decoder.eventName.
        // If the event is not successfully decoded (e.g. if the
        // event is not an event with name decoder.eventName),
        // the catch will be hit.
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
      // Event was not decoded by any decoder so return null.
      return null;
    })
    // Filter out all nulls so that at the end we are left with
    // only successfully decoded events.
    .filter(Boolean);
  return decodedEvents as DecodedTransactionEvent[];
}
