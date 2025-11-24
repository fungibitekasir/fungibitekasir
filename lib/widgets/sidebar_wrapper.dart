import 'package:flutter/material.dart';
import 'sidebar.dart';

class SidebarWrapper extends StatefulWidget {
  final Widget child;
  final String storeId;
  final String role;

  const SidebarWrapper({
    super.key,
    required this.child,
    required this.storeId,
    required this.role,
  });

  @override
  State<SidebarWrapper> createState() => _SidebarWrapperState();
}

class _SidebarWrapperState extends State<SidebarWrapper> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(-1.0, 0), // mulai di luar layar kiri
      end: Offset.zero, // posisi final
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  void _toggleSidebar() {
    if (_controller.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 8,
          left: 20,
          child: GestureDetector(
            onTap: _toggleSidebar,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFDECC8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.menu, color: Color(0xFF8B5E3C), size: 26),
            ),
          ),
        ),
        SlideTransition(
          position: _slideAnimation,
          child: SafeArea(
            child: CombinedSidebar(
              storeId: widget.storeId,
              role: widget.role,
              onClose: _toggleSidebar,
            ),
          ),
        ),
      ],
    );
  }
}
