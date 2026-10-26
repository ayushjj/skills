/**
 * LLM accuracy measurement template — adapt for each tuning session.
 * Measures baseline accuracy and compares prompt approaches.
 *
 * Usage:
 *   pnpm tsx scripts/measure-accuracy.ts
 */

interface TestCase {
  input: string;
  expected: string;  // Expected output/classification
  category: string;  // Edge case category
  notes?: string;    // Why this case matters
}

// Minimum 10 test cases: 3+ positive, 3+ negative, 3+ edge cases
export const testCases: TestCase[] = [
  // Happy path cases (3-4)
  { input: "Win a free phone! Click here now", expected: "spam", category: "clear_spam" },

  // Edge cases (3-4)
  { input: "Your invoice is attached, click here to pay", expected: "not_spam", category: "spam_like_wording" },

  // Negative cases (3-4)
  { input: "Lunch at 1pm tomorrow?", expected: "not_spam", category: "clear_not_spam" },
];

async function measureAccuracy(prompt: string): Promise<{
  accuracy: number;
  failures: Array<TestCase & { actual: string }>;
}> {
  let correct = 0;
  const failures: Array<TestCase & { actual: string }> = [];

  for (const tc of testCases) {
    const result = await runLLM(prompt, tc.input);
    if (result === tc.expected) {
      correct++;
    } else {
      failures.push({ ...tc, actual: result });
    }
  }

  return {
    accuracy: correct / testCases.length,
    failures,
  };
}

async function runLLM(prompt: string, input: string): Promise<string> {
  // Replace with actual LLM call
  throw new Error('Implement runLLM with your LLM client');
}

async function main() {
  const prompt = ''; // Your current prompt
  const { accuracy, failures } = await measureAccuracy(prompt);

  console.log(`\n=== Baseline Accuracy ===`);
  console.log(`Accuracy: ${(accuracy * 100).toFixed(1)}% (${testCases.length - failures.length}/${testCases.length} correct)`);

  if (failures.length > 0) {
    console.log(`\nFailures:`);
    for (const f of failures) {
      console.log(`  [${f.category}] "${f.input}"`);
      console.log(`    Expected: ${f.expected}, Got: ${f.actual}`);
    }
  }
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
