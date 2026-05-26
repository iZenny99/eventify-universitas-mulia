import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import '../../features/events/domain/event_model.dart';
import '../../features/events/data/event_repository.dart';
import '../theme/app_colors.dart';

class EventCard extends StatefulWidget {
  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.enableHero = true,
  });

  final EventModel event;
  final VoidCallback? onTap;
  final bool enableHero;

  @override
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  final _eventRepository = EventRepository();
  bool _isBookmarked = false;
  bool _isLoadingBookmark = false;

  @override
  void initState() {
    super.initState();
    _checkBookmarkStatus();
    EventRepository.bookmarkToggleNotifier.addListener(_onGlobalBookmarkToggle);
  }

  void _onGlobalBookmarkToggle() {
    final payload = EventRepository.bookmarkToggleNotifier.value;
    if (payload != null && payload['eventId'] == widget.event.id) {
      if (mounted) {
        setState(() {
          _isBookmarked = payload['isBookmarked'];
        });
      }
    }
  }

  @override
  void dispose() {
    EventRepository.bookmarkToggleNotifier.removeListener(_onGlobalBookmarkToggle);
    super.dispose();
  }

  Future<void> _checkBookmarkStatus() async {
    final isBookmarked = await _eventRepository.checkIsBookmarked(widget.event.id);
    if (mounted) {
      setState(() {
        _isBookmarked = isBookmarked;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    if (_isLoadingBookmark) return;
    setState(() {
      _isLoadingBookmark = true;
      _isBookmarked = !_isBookmarked; // Optimistic update
    });

    final newStatus = await _eventRepository.toggleBookmark(widget.event.id, !_isBookmarked);
    
    if (mounted) {
      setState(() {
        _isBookmarked = newStatus;
        _isLoadingBookmark = false;
      });
    }
  }

  void _handleShare() {
    // ignore: deprecated_member_use
    Share.share(
      '🎓 Ikuti ${widget.event.categoryName}: ${widget.event.title}\n📍 ${widget.event.locationName}\n\n${widget.event.shortDescription ?? ""}\n\nDaftar sekarang:\nhttps://eventify.app/event/${widget.event.id}',
      subject: 'Event Eventify: ${widget.event.title}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          highlightColor: AppColors.primary.withValues(alpha: 0.05),
          splashColor: AppColors.primary.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: widget.enableHero
                      ? Hero(tag: 'event_${widget.event.id}', child: _buildPoster())
                      : _buildPoster(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              (widget.event.categoryName ?? 'EVENT').toUpperCase(),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: _handleShare,
                                child: Icon(Icons.share_outlined, size: 18, color: AppColors.textSecondary),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: _toggleBookmark,
                                child: Icon(
                                  _isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  size: 18,
                                  color: _isBookmarked ? AppColors.primary : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.event.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              widget.event.locationName,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPoster() {
    return Container(
      width: 90,
      height: 90,
      color: AppColors.primary.withValues(alpha: 0.1),
      child: (widget.event.posterUrl != null && widget.event.posterUrl!.startsWith('http'))
          ? CachedNetworkImage(
              imageUrl: widget.event.posterUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) =>
                  Icon(Icons.event_available, color: AppColors.primary),
            )
          : Icon(Icons.event_available, color: AppColors.primary),
    );
  }
}
