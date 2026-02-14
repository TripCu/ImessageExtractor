import { useMemo } from "react";

type PlaceholderItem =
  | { kind: "separator"; label: string }
  | {
      kind: "message";
      id: string;
      outgoing: boolean;
      widthPercent: number;
      text: string;
    };

interface FakeChatPaneProps {
  seed: string;
  showTodaySeparator?: boolean;
}

function hashSeed(seed: string): number {
  let hash = 0;
  for (let i = 0; i < seed.length; i += 1) {
    hash = (hash << 5) - hash + seed.charCodeAt(i);
    hash |= 0;
  }
  return hash >>> 0;
}

function mulberry32(seed: number): () => number {
  let state = seed;
  return () => {
    state |= 0;
    state = (state + 0x6d2b79f5) | 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t ^= t + Math.imul(t ^ (t >>> 7), 61 | t);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

const WORD_BANK = [
  "placeholder",
  "stable",
  "layout",
  "masked",
  "preview",
  "export",
  "conversation",
  "bubble",
  "deterministic",
  "private",
  "secure",
  "sample",
  "draft",
  "thread",
  "abstract",
  "visual"
];

function buildText(random: () => number): string {
  const words = 4 + Math.floor(random() * 8);
  const chosen: string[] = [];
  for (let i = 0; i < words; i += 1) {
    const index = Math.floor(random() * WORD_BANK.length);
    chosen.push(WORD_BANK[index]);
  }
  return chosen.join(" ");
}

function buildPlaceholderItems(seed: string, showSeparator: boolean): PlaceholderItem[] {
  const random = mulberry32(hashSeed(seed));
  const items: PlaceholderItem[] = [];
  const total = 14;
  const separatorIndex = 5 + Math.floor(random() * 4);

  for (let i = 0; i < total; i += 1) {
    if (showSeparator && i === separatorIndex) {
      items.push({ kind: "separator", label: "Today" });
    }

    items.push({
      kind: "message",
      id: `placeholder-${i}`,
      outgoing: random() >= 0.5,
      widthPercent: 36 + Math.floor(random() * 35),
      text: buildText(random)
    });
  }

  return items;
}

export default function FakeChatPane({
  seed,
  showTodaySeparator = true
}: FakeChatPaneProps): JSX.Element {
  const items = useMemo(() => buildPlaceholderItems(seed, showTodaySeparator), [seed, showTodaySeparator]);

  return (
    <div className="h-full overflow-y-auto px-5 py-4">
      <div className="mx-auto flex max-w-4xl flex-col gap-2">
        {items.map((item) => {
          if (item.kind === "separator") {
            return (
              <div key={`sep-${item.label}`} className="my-3 flex justify-center">
                <span className="rounded-full border border-[var(--border-hairline)] px-3 py-0.5 text-xs text-[var(--text-secondary)]">
                  {item.label}
                </span>
              </div>
            );
          }

          return (
            <div key={item.id} className={`flex ${item.outgoing ? "justify-end" : "justify-start"}`}>
              <div
                className={`rounded-[var(--radius-bubble)] px-4 py-2 text-sm leading-6 ${
                  item.outgoing
                    ? "bg-[var(--accent)]/90 text-white"
                    : "border border-[var(--border-hairline)] bg-black/5 text-[var(--text-primary)] dark:bg-white/5"
                }`}
                style={{ maxWidth: "70%", width: `${item.widthPercent}%` }}
                aria-label="Deterministic placeholder message"
              >
                <span
                  className="select-none"
                  style={{
                    filter: "blur(5px)",
                    WebkitFilter: "blur(5px)"
                  }}
                >
                  {item.text}
                </span>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
