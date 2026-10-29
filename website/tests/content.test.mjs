import test from "node:test";
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
const read = async (p) =>
  JSON.parse(await readFile(new URL(p, import.meta.url), "utf8"));
const units = await read("../src/content/course.json");
const native = await read("../../docs/website/lessons.json");
const lessons = units.flatMap((u) => u.lessons),
  ids = new Set(lessons.map((l) => l.id));
test("all original native visual guides are preserved without changing their content", async () => {
  const guides = await read("../../GopherForge/Resources/LessonGuides.json");
  assert.equal(lessons.filter((l) => l.guide).length, guides.length);
  for (const guide of guides)
    assert.deepEqual(lessons.find((l) => l.id === guide.id)?.guide, guide);
});
test("web catalog is the exact native public export, with stable unique routes", () => {
  assert.deepEqual(units, native);
  assert.equal(ids.size, lessons.length);
  for (const l of lessons) assert.match(l.id, /^[a-z0-9.-]+$/);
});

test("reading text, examples and checks match the current native resources", async () => {
  const readings = await read(
    "../../GopherForge/Resources/ReadingLessons.json",
  );
  assert.equal(
    lessons.filter((l) => l.kind === "reading").length,
    readings.length,
  );
  for (const reading of readings) {
    const exported = lessons.find((l) => l.id === reading.id);
    assert.equal(exported?.explanation, reading.introduction, reading.id);
    const sections = reading.sections.map((section) =>
      Object.fromEntries(
        Object.entries(section).filter(([, value]) => value !== null),
      ),
    );
    assert.deepEqual(exported.reading.sections, sections, reading.id);
    assert.equal(exported.reading.takeaway, reading.takeaway, reading.id);
    assert.deepEqual(
      exported.reading.references,
      reading.references,
      reading.id,
    );
    assert.equal(
      exported.reading.quiz.correct,
      reading.reviewAnswer,
      reading.id,
    );
    assert.deepEqual(
      exported.reading.quiz.alternatives,
      reading.wrongAnswers,
      reading.id,
    );
  }
});
test("reading self-checks have three distinct options and corrective explanations", () => {
  for (const l of lessons.filter((l) => l.kind === "reading")) {
    const q = l.reading.quiz;
    assert.ok(q, l.id);
    assert.equal(new Set([q.correct, ...q.alternatives]).size, 3, l.id);
    assert.equal(q.alternatives.length, 2);
    assert.ok(q.explanation.length > 30);
    assert.ok(l.reading.sections.length >= 3);
  }
});
test("public export does not expose hidden compiler tests or verified exercise solutions", () => {
  for (const l of lessons)
    for (const key of [
      "test",
      "hiddenTests",
      "idiomaticSolution",
      "solution",
      "expectedOutput",
    ])
      assert.equal(key in l, false, `${l.id}.${key}`);
});
test("every article related lesson exists and every slug is unique", async () => {
  const posts = await read("../src/content/posts.json");
  assert.equal(new Set(posts.map((p) => p.slug)).size, posts.length);
  for (const p of posts) {
    assert.ok(p.sections.length >= 4);
    for (const id of p.related)
      assert.ok(ids.has(id), `${p.slug}: missing ${id}`);
  }
});
test("architecture ratings preserve all three scenarios and support links to real lessons", () => {
  const styles = units
    .find((u) => u.id === "architecture")
    .lessons.filter((l) => l.reading.designGuide.ratings.length);
  assert.equal(styles.length, 17);
  for (const l of styles) {
    assert.equal(l.reading.designGuide.ratings.length, 3);
    for (const r of l.reading.designGuide.ratings)
      assert.ok(r.score >= 1 && r.score <= 5);
  }
});

test("learning directions contain every native unit exactly once", async () => {
  const { directions } = await import("../src/lib/course-map.ts");
  const all = directions.flatMap((d) => [...d.units]);
  assert.equal(new Set(all).size, all.length);
  assert.deepEqual(new Set(all), new Set(units.map((u) => u.id)));
  for (const d of directions) {
    assert.ok(d.title && d.description);
    assert.ok(d.units.length > 0);
  }
});
test("interview guides and computed traces match the bundled native bank", async () => {
  const bank = await read("../src/content/interview.json");
  assert.deepEqual(
    bank,
    await read("../../GopherForge/Resources/InterviewPrep.json"),
  );
  assert.equal(bank.questions.length, 132);
  assert.equal(new Set(bank.questions.map((q) => q.id)).size, 132);
  assert.equal(bank.demonstrations.length, 12);
  assert.equal(bank.demonstrations.flatMap((d) => d.cases).length, 36);
  for (const q of bank.questions) {
    assert.ok(q.answerPoints.length >= 3, q.id);
    assert.ok(q.solution.length > 80, q.id);
    assert.ok(q.trap && q.followUp, q.id);
    assert.ok(bank.topics.some((t) => t.id === q.topic));
    assert.ok(q.level >= 1 && q.level <= 4);
  }
  for (const d of bank.demonstrations)
    for (const c of d.cases) {
      assert.ok(c.result);
      assert.ok(c.steps.length);
      for (const s of c.steps)
        for (const r of s.rows)
          assert.ok(r.active.every((i) => i >= 0 && i < r.values.length));
    }
});

test("interview directions contain every topic exactly once", async () => {
  const { interviewDirections } = await import("../src/lib/interview-map.ts");
  const interview = await read("../src/content/interview.json");
  const ids = interviewDirections.flatMap((d) => d.topics);
  assert.equal(ids.length, new Set(ids).size);
  assert.deepEqual([...ids].sort(), interview.topics.map((t) => t.id).sort());
});
