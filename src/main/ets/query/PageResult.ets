/** Pagination model carrying the result of `findPage(page, size)`. */
export class PageResult<T> {
  data: T[];
  total: number;
  page: number;
  totalPages: number;

  constructor(data: T[], total: number, page: number, totalPages: number) {
    this.data = data;
    this.total = total;
    this.page = page;
    this.totalPages = totalPages;
  }
}
