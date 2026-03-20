import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  int selectedTab = 0;
  int selectedBottomIndex = 2;

  final List<String> tabs = <String>['Todas', 'Vencimiento', 'Recetas', 'Info'];

  final List<_NotificationItem> notifications = <_NotificationItem>[
    const _NotificationItem(
      time: 'HACE 10 MIN',
      title: '¡El aguacate vence mañana!',
      subtitle: 'Úsalo hoy en un guacamole...',
      icon: Icons.alarm,
      iconColor: Color(0xFFE92D2D),
      iconBackground: Color(0xFFF7D6DC),
    ),
    const _NotificationItem(
      time: 'HACE 1 HORA',
      title: 'Recuerda consumir la leche',
      subtitle: 'Mejor antes de que pierda frescura...',
      icon: Icons.notifications_active,
      iconColor: Color(0xFFC78500),
      iconBackground: Color(0xFFF4E9B2),
    ),
    const _NotificationItem(
      time: 'HACE 3 HORAS',
      title: 'Nueva receta sugerida',
      subtitle: 'Smoothie energético de frutos rojos...',
      icon: Icons.restaurant,
      iconColor: Color(0xFF2F8E40),
      iconBackground: Color(0xFFD4E8D6),
    ),
    const _NotificationItem(
      time: 'AYER',
      title: 'Resumen semanal listo',
      subtitle: 'Ahorraste un 15% más que la semana anterior...',
      icon: Icons.insert_chart,
      iconColor: Color(0xFF4A5E7A),
      iconBackground: Color(0xFFE1E6ED),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: <Widget>[
                  _RoundIconButton(
                    icon: Icons.arrow_back,
                    onTap: () {},
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Notificaciones',
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 50,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemBuilder: (BuildContext context, int index) {
                  final bool isSelected = index == selectedTab;
                  return GestureDetector(
                    onTap: () => setState(() => selectedTab = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary500 : AppColors.gray50,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        tabs[index],
                        style: TextStyle(
                          fontFamily: 'Montserrat',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                },
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(width: 12);
                },
                itemCount: tabs.length,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                itemCount: notifications.length,
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(height: 16);
                },
                itemBuilder: (BuildContext context, int index) {
                  final _NotificationItem item = notifications[index];
                  return _NotificationCard(item: item);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFDCE3EA))),
        ),
        child: BottomNavigationBar(
          currentIndex: selectedBottomIndex,
          onTap: (int value) => setState(() => selectedBottomIndex = value),
          backgroundColor: Colors.white,
          elevation: 0,
          selectedItemColor: AppColors.primary500,
          unselectedItemColor: AppColors.gray400,
          selectedLabelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Montserrat',
            fontWeight: FontWeight.w700,
            fontSize: 11,
          ),
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              label: 'INICIO',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              label: 'DESPENSA',
            ),
            BottomNavigationBarItem(
              icon: Container(
                width: 50,
                height: 50,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary500,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 30),
              ),
              label: '',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.menu_book_outlined),
              label: 'RECETAS',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              label: 'PERFIL',
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final _NotificationItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: item.iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.iconColor, size: 34),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.time,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppColors.textTertiary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Montserrat',
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gray50,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: AppColors.textSecondary, size: 28),
        ),
      ),
    );
  }
}

class _NotificationItem {
  const _NotificationItem({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });

  final String time;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
}
