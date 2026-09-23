/**
 * Simple promise-based mutex. Used to prevent concurrent opening (race
 * condition) of the same database during `ArkORM.init`.
 *
 * Queue: each `acquire` call waits for the previous owner to release.
 */
export class AsyncLock {
  private queue: Promise<void> = Promise.resolve();

  /**
   * Acquires the lock and holds it while `fn` runs; releases automatically when
   * `fn` finishes (even on error). Returns `fn`'s result.
   */
  async runExclusive<T>(fn: () => Promise<T>): Promise<T> {
    const previous: Promise<void> = this.queue;
    let release: () => void = (): void => {};
    this.queue = new Promise<void>((resolve: () => void): void => {
      release = resolve;
    });

    await previous;
    try {
      return await fn();
    } finally {
      release();
    }
  }
}
