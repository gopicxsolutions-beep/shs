/// One page of a keyset-paginated live-mode query, plus whether more rows
/// exist beyond it.
///
/// Backs the "Load more" pattern on [AdminUsersPage]/[AdminShgsPage] (see
/// `AdminRepository.fetchAllUsers`/`ShgRepository.fetchAllShgs`), which
/// previously hard-capped a single query at `.limit(500)` ordered
/// alphabetically with no pagination UI at all — any user/SHG past the
/// 500th name was silently invisible and permanently unreachable, with no
/// signal to the admin that anything had been truncated. Demo mode's fixed,
/// small mock lists have no real pagination need, so their branch always
/// returns everything in one page (`hasMore: false`).
class PagedResult<T> {
  final List<T> items;
  final bool hasMore;
  const PagedResult({required this.items, required this.hasMore});
}
