import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// صورة شبكية مرنة: إعادة محاولة تلقائية + صورة بديلة عند الفشل
/// (بتتجنب خطأ "Connection closed before full header" بتاع Cloudinary)
class AppNetworkImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color? fallbackColor;

  const AppNetworkImage({
    super.key,
    this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.fallbackIcon = Icons.image_not_supported_rounded,
    this.fallbackColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = url != null && url!.trim().isNotEmpty;
    final child = hasUrl
        ? CachedNetworkImage(
            imageUrl: url!,
            fit: fit,
            width: width,
            height: height,
            fadeInDuration: const Duration(milliseconds: 200),
            placeholder: (context, url) => Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fallbackColor ?? Theme.of(context).primaryColor,
                ),
              ),
            ),
            errorWidget: (context, url, error) => Icon(
              fallbackIcon,
              size: (width != null && width! < 60) ? 20 : 32,
              color: (fallbackColor ?? Colors.grey).withValues(alpha: 0.6),
            ),
          )
        : Icon(
            fallbackIcon,
            size: (width != null && width! < 60) ? 20 : 32,
            color: (fallbackColor ?? Colors.grey).withValues(alpha: 0.6),
          );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }
}

/// صورة بروفايل (Avatar) مرنة مع صورة بديلة عند الفشل
class AppCircleAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final Color? backgroundColor;
  final IconData fallbackIcon;

  const AppCircleAvatar({
    super.key,
    this.imageUrl,
    this.radius = 20,
    this.backgroundColor,
    this.fallbackIcon = Icons.person_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final hasUrl = imageUrl != null && imageUrl!.trim().isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? Colors.grey.shade300,
      child: hasUrl
          ? ClipOval(
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                width: radius * 2,
                height: radius * 2,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (context, url) => const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => Icon(fallbackIcon, size: radius, color: Colors.grey),
              ),
            )
          : Icon(fallbackIcon, size: radius, color: Colors.grey),
    );
  }
}
