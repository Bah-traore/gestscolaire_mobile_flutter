import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/app_theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/custom_button.dart';
import '../providers/parent_context_provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/establishments_service.dart';
import '../services/children_service.dart';
import '../services/modules_service.dart';
import '../utils/user_friendly_errors.dart';
import 'package:dio/dio.dart';

/// Écran du tableau de bord
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  bool _loadingEstablishments = false;
  String? _establishmentsError;
  List<Map<String, dynamic>> _establishments = const [];

  bool _loadingChildren = false;
  String? _childrenError;
  List<Map<String, dynamic>> _children = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadEstablishments();
      final ctx = context.read<ParentContextProvider>();
      if (ctx.hasEstablishment) {
        _loadChildren();
      }
    });
  }

  Future<void> _loadEstablishments() async {
    setState(() {
      _loadingEstablishments = true;
      _establishmentsError = null;
    });

    try {
      final api = context.read<ApiService>();
      final auth = context.read<AuthProvider>();
      final service = EstablishmentsService(api);

      final identifier =
          ((auth.currentUser?.email ?? '').toString().trim().isNotEmpty)
          ? (auth.currentUser?.email ?? '').toString().trim()
          : (auth.currentUser?.phone ?? '').toString().trim();
      if (identifier.isEmpty) {
        throw Exception('Identifiant (email ou téléphone) requis');
      }

      final items = await service.discover(identifier: identifier);
      setState(() {
        _establishments = items;
      });

      // Ne pas auto-sélectionner une école : le parent choisit toujours manuellement.
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        try {
          final authService = context.read<AuthService>();
          final refreshed = await authService.refreshAccessToken();
          if (refreshed) {
            final api = context.read<ApiService>();
            final auth = context.read<AuthProvider>();
            final service = EstablishmentsService(api);

            final identifier =
                ((auth.currentUser?.email ?? '').toString().trim().isNotEmpty)
                ? (auth.currentUser?.email ?? '').toString().trim()
                : (auth.currentUser?.phone ?? '').toString().trim();
            if (identifier.isNotEmpty) {
              final items = await service.discover(identifier: identifier);
              setState(() {
                _establishments = items;
              });
              return;
            }
          }
        } catch (_) {
          // ignore and fallthrough
        }

        setState(() {
          _establishmentsError =
              'Votre session a expiré. Veuillez vous reconnecter.';
        });
        return;
      }

      setState(() {
        _establishmentsError = UserFriendlyErrors.fromDio(e);
      });
    } catch (e) {
      setState(() {
        _establishmentsError = UserFriendlyErrors.from(e);
      });
    } finally {
      setState(() {
        _loadingEstablishments = false;
      });
    }
  }

  Future<void> _loadChildren() async {
    setState(() {
      _loadingChildren = true;
      _childrenError = null;
    });

    try {
      final ctx = context.read<ParentContextProvider>();
      final est = ctx.establishment;
      if (est == null) {
        setState(() {
          _children = const [];
        });
        return;
      }

      final api = context.read<ApiService>();
      final service = ChildrenService(api);
      final items = await service.fetchChildren(establishmentId: est.subdomain);
      setState(() {
        _children = items;
      });
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        try {
          final authService = context.read<AuthService>();
          final refreshed = await authService.refreshAccessToken();
          if (refreshed) {
            final ctx = context.read<ParentContextProvider>();
            final est = ctx.establishment;
            if (est != null) {
              final api = context.read<ApiService>();
              final service = ChildrenService(api);
              final items = await service.fetchChildren(
                establishmentId: est.subdomain,
              );
              setState(() {
                _children = items;
              });
              return;
            }
          }
        } catch (_) {
          // ignore
        }
        setState(() {
          _childrenError = 'Votre session a expiré. Veuillez vous reconnecter.';
        });
        return;
      }

      setState(() {
        _childrenError = UserFriendlyErrors.fromDio(e);
      });
    } catch (e) {
      setState(() {
        _childrenError = UserFriendlyErrors.from(e);
      });
    } finally {
      setState(() {
        _loadingChildren = false;
      });
    }
  }

  Future<void> _selectEstablishment(Map<String, dynamic> est) async {
    final subdomain = (est['id'] ?? '').toString();
    final name = (est['name'] ?? '').toString();
    if (subdomain.isEmpty) {
      return;
    }

    setState(() {
      _loadingEstablishments = true;
      _establishmentsError = null;
    });

    try {
      final api = context.read<ApiService>();
      final service = EstablishmentsService(api);

      final resp = await service.switchEstablishment(
        establishmentId: subdomain,
      );
      final estData = resp['establishment'];
      if (estData is! Map) {
        throw Exception('Réponse établissement invalide');
      }

      final tenantIdRaw = estData['tenant_id'];
      final tenantId = tenantIdRaw is int
          ? tenantIdRaw
          : int.tryParse((tenantIdRaw ?? '').toString());
      if (tenantId == null) {
        throw Exception('tenant_id manquant');
      }

      final ctx = context.read<ParentContextProvider>();
      ctx.setEstablishment(
        SelectedEstablishment(
          subdomain: subdomain,
          tenantId: tenantId,
          name: (estData['name'] ?? name).toString(),
          logo: estData['logo']?.toString(),
          city: estData['city']?.toString(),
        ),
      );

      final accessToken = resp['access_token'];
      final refreshToken = resp['refresh_token'];
      if (accessToken is String && accessToken.isNotEmpty) {
        final authService = context.read<AuthService>();
        await authService.setTokens(
          accessToken: accessToken,
          refreshToken: refreshToken is String ? refreshToken : null,
        );
      }

      if (!mounted) return;
      setState(() {
        _children = const [];
        _childrenError = null;
      });
      await _loadChildren();
    } catch (e) {
      setState(() {
        _establishmentsError = UserFriendlyErrors.from(e);
      });
    } finally {
      setState(() {
        _loadingEstablishments = false;
      });
    }
  }

  Future<void> _selectChild(Map<String, dynamic> child) async {
    final idRaw = child['id'];
    final id = idRaw is int ? idRaw : int.tryParse((idRaw ?? '').toString());
    if (id == null) return;

    final fullName = (child['full_name'] ?? '').toString();
    final className = (child['class_name'] ?? '').toString();

    final ctx = context.read<ParentContextProvider>();
    ctx.setChild(
      SelectedChild(
        id: id,
        fullName: fullName.isNotEmpty ? fullName : 'Élève $id',
        className: className.isNotEmpty ? className : null,
      ),
    );
  }

  Future<void> _openModule(BuildContext context, String module) async {
    final ctx = context.read<ParentContextProvider>();

    if (!ctx.hasEstablishment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une école.')),
      );
      return;
    }

    if (!ctx.hasChild) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir un élève.')),
      );
      return;
    }

    final tenant = ctx.establishment!.subdomain;
    final eleveId = ctx.child!.id;

    try {
      final api = context.read<ApiService>();
      final authService = context.read<AuthService>();
      final service = ModulesService(api);

      Map<String, dynamic> resp;
      Future<Map<String, dynamic>> run() {
        switch (module) {
          case 'notes':
            return service.fetchNotes(tenant: tenant, eleveId: eleveId);
          case 'homework':
            return service.fetchHomework(tenant: tenant, eleveId: eleveId);
          case 'bulletins':
            return service.fetchBulletins(tenant: tenant, eleveId: eleveId);
          case 'notifications':
            return service.fetchNotifications(tenant: tenant, eleveId: eleveId);
          case 'scolarites':
            return service.fetchScolarites(tenant: tenant, eleveId: eleveId);
          default:
            return Future.value(<String, dynamic>{});
        }
      }

      try {
        resp = await run();
      } on DioException catch (e) {
        if (e.response?.statusCode == 401) {
          final refreshed = await authService.refreshAccessToken();
          if (refreshed) {
            resp = await run();
          } else {
            await authService.logout();
            if (!mounted) return;
            Navigator.of(
              context,
            ).pushNamedAndRemoveUntil('/login', (route) => false);
            return;
          }
        } else {
          rethrow;
        }
      }

      int? count;
      final listCandidate =
          resp['results'] ??
          resp['data'] ??
          resp['items'] ??
          resp['notes'] ??
          resp['homework'] ??
          resp['bulletins'] ??
          resp['notifications'] ??
          resp['scolarites'];
      if (listCandidate is List) {
        count = listCandidate.length;
      }

      final label = switch (module) {
        'notes' => 'Notes',
        'homework' => 'Devoirs',
        'bulletins' => 'Bulletins',
        'notifications' => 'Notifications',
        'scolarites' => 'Scolarités',
        _ => 'Module',
      };

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == null
                ? '$label chargé.'
                : '$label chargé ($count élément(s)).',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(UserFriendlyErrors.from(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Tableau de bord'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.md),
            child: Center(
              child: Consumer<AuthProvider>(
                builder: (context, authProvider, _) {
                  final user = authProvider.currentUser;
                  return Text(
                    user?.fullName ?? 'Utilisateur',
                    style: Theme.of(context).textTheme.titleMedium,
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Carte de bienvenue
            _buildWelcomeCard(context),

            const SizedBox(height: AppTheme.lg),

            _buildEstablishmentsSection(context),

            const SizedBox(height: AppTheme.lg),

            _buildChildrenSection(context),

            const SizedBox(height: AppTheme.xl),

            // Grille de fonctionnalités
            _buildFeaturesGrid(context),

            const SizedBox(height: AppTheme.xl),

            // Statistiques rapides
            _buildQuickStats(context),

            const SizedBox(height: AppTheme.xl),

            // Bouton de déconnexion
            CustomButton(
              label: 'Se déconnecter',
              backgroundColor: AppTheme.errorColor,
              onPressed: () => _handleLogout(context),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Accueil'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Emploi du temps',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.grade), label: 'Notes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
        ],
      ),
    );
  }

  Widget _buildEstablishmentsSection(BuildContext context) {
    return Consumer<ParentContextProvider>(
      builder: (context, parentCtx, _) {
        final current = parentCtx.establishment;
        final selectedSubdomain = current?.subdomain;

        return Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: const [AppTheme.shadowSmall],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mes écoles',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _loadingEstablishments
                        ? null
                        : _loadEstablishments,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.md),
              if (_loadingEstablishments)
                const Center(child: CircularProgressIndicator())
              else if (_establishmentsError != null)
                Text(
                  _establishmentsError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.errorColor),
                )
              else if (_establishments.isEmpty)
                Text(
                  'Aucune école disponible',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _establishments.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppTheme.md),
                    itemBuilder: (context, index) {
                      final est = _establishments[index];
                      final name = (est['name'] ?? '').toString();
                      final logo = est['logo']?.toString();
                      final countRaw = est['children_count'];
                      final count = countRaw is int
                          ? countRaw
                          : int.tryParse((countRaw ?? '').toString());

                      final isSelected =
                          (est['id'] ?? '').toString() ==
                          (selectedSubdomain ?? '');

                      final hasLogo = (logo ?? '').trim().isNotEmpty;

                      return InkWell(
                        onTap: () => _selectEstablishment(est),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        child: Opacity(
                          opacity: isSelected || selectedSubdomain == null
                              ? 1
                              : 0.55,
                          child: SizedBox(
                            width: 86,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: isSelected
                                            ? const [AppTheme.shadowSmall]
                                            : const [],
                                        color: isSelected
                                            ? AppTheme.primaryColor.withOpacity(
                                                0.18,
                                              )
                                            : AppTheme.primaryColor.withOpacity(
                                                0.08,
                                              ),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : AppTheme.borderColor,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: hasLogo
                                            ? Image.network(
                                                logo!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                      Icons.school,
                                                      color:
                                                          AppTheme.primaryColor,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.school,
                                                color: AppTheme.primaryColor,
                                              ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        left: -4,
                                        top: -4,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppTheme.surfaceColor,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    if (count != null)
                                      Positioned(
                                        right: -4,
                                        top: -4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppTheme.sm,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor
                                                .withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: AppTheme.borderColor,
                                            ),
                                          ),
                                          child: Text(
                                            '$count',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: AppTheme.primaryColor,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.sm),
                                Text(
                                  name.isNotEmpty ? name : 'École',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppTheme.sm),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChildrenSection(BuildContext context) {
    return Consumer<ParentContextProvider>(
      builder: (context, parentCtx, _) {
        if (!parentCtx.hasEstablishment) {
          return const SizedBox.shrink();
        }

        final selectedChildId = parentCtx.child?.id;

        return Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: const [AppTheme.shadowSmall],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mes enfants',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _loadingChildren ? null : _loadChildren,
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.md),
              if (_loadingChildren)
                const Center(child: CircularProgressIndicator())
              else if (_childrenError != null)
                Text(
                  _childrenError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.errorColor),
                )
              else if (_children.isEmpty)
                Text(
                  'Aucun enfant',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                SizedBox(
                  height: 104,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _children.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppTheme.md),
                    itemBuilder: (context, index) {
                      final child = _children[index];
                      final idRaw = child['id'];
                      final id = idRaw is int
                          ? idRaw
                          : int.tryParse((idRaw ?? '').toString());
                      final fullName = (child['full_name'] ?? '').toString();
                      final photo =
                          (child['profile_picture'] ?? child['photo'] ?? '')
                              .toString();
                      final hasPhoto = photo.trim().isNotEmpty;

                      final isSelected = id != null && id == selectedChildId;

                      return InkWell(
                        onTap: () => _selectChild(child),
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusLarge,
                        ),
                        child: Opacity(
                          opacity: isSelected || selectedChildId == null
                              ? 1
                              : 0.55,
                          child: SizedBox(
                            width: 86,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        boxShadow: isSelected
                                            ? const [AppTheme.shadowSmall]
                                            : const [],
                                        color: isSelected
                                            ? AppTheme.primaryColor.withOpacity(
                                                0.18,
                                              )
                                            : AppTheme.primaryColor.withOpacity(
                                                0.08,
                                              ),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppTheme.primaryColor
                                              : AppTheme.borderColor,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: hasPhoto
                                            ? Image.network(
                                                photo,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    const Icon(
                                                      Icons.person,
                                                      color:
                                                          AppTheme.primaryColor,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.person,
                                                color: AppTheme.primaryColor,
                                              ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        left: -4,
                                        top: -4,
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: AppTheme.primaryColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppTheme.surfaceColor,
                                              width: 2,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: AppTheme.sm),
                                Text(
                                  fullName.isNotEmpty ? fullName : 'Enfant',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: AppTheme.sm),
            ],
          ),
        );
      },
    );
  }

  /// Construire la carte de bienvenue
  Widget _buildWelcomeCard(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.currentUser;

        return Container(
          padding: const EdgeInsets.all(AppTheme.lg),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.8),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
            boxShadow: const [AppTheme.shadowMedium],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bienvenue!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppTheme.sm),
              Text(
                user?.fullName ?? 'Utilisateur',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: AppTheme.md),
              Text(
                'Vous êtes connecté en tant que ${user?.userType ?? 'utilisateur'}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Construire la grille de fonctionnalités
  Widget _buildFeaturesGrid(BuildContext context) {
    final features = [
      {
        'icon': Icons.calendar_today,
        'title': 'Emploi du temps',
        'description': 'Voir votre emploi du temps',
      },
      {
        'icon': Icons.grade,
        'title': 'Notes',
        'description': 'Consulter vos notes',
      },
      {
        'icon': Icons.assignment,
        'title': 'Devoirs',
        'description': 'Voir les devoirs',
      },
      {
        'icon': Icons.notifications,
        'title': 'Notifications',
        'description': 'Vos messages',
      },
      {
        'icon': Icons.insert_drive_file,
        'title': 'Bulletins',
        'description': 'Voir les bulletins',
      },
      {
        'icon': Icons.payments,
        'title': 'Scolarités',
        'description': 'Voir les paiements',
      },
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppTheme.lg,
        mainAxisSpacing: AppTheme.lg,
        childAspectRatio: 1,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];

        return GestureDetector(
          onTap: () {
            if (feature['title'] == 'Emploi du temps') {
              _openTimetableFlow(context);
              return;
            }

            if (feature['title'] == 'Notes') {
              _openModule(context, 'notes');
              return;
            }

            if (feature['title'] == 'Devoirs') {
              _openModule(context, 'homework');
              return;
            }

            if (feature['title'] == 'Notifications') {
              _openModule(context, 'notifications');
              return;
            }

            if (feature['title'] == 'Bulletins') {
              _openModule(context, 'bulletins');
              return;
            }

            if (feature['title'] == 'Scolarités') {
              _openModule(context, 'scolarites');
              return;
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [AppTheme.shadowSmall],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: Icon(
                    feature['icon'] as IconData,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppTheme.md),
                Text(
                  feature['title'] as String,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppTheme.xs),
                Text(
                  feature['description'] as String,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Construire les statistiques rapides
  Widget _buildQuickStats(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Statistiques rapides',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppTheme.lg),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.check_circle,
                title: 'Présences',
                value: '95%',
                color: AppTheme.successColor,
              ),
            ),
            const SizedBox(width: AppTheme.lg),
            Expanded(
              child: _buildStatCard(
                context,
                icon: Icons.trending_up,
                title: 'Moyenne',
                value: '14.5',
                color: AppTheme.infoColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Construire une carte de statistique
  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.lg),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: AppTheme.md),
          Text(title, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: AppTheme.sm),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  void _openTimetableFlow(BuildContext context) {
    final ctx = context.read<ParentContextProvider>();

    if (!ctx.hasEstablishment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une école.')),
      );
      return;
    }

    if (!ctx.hasChild) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir un élève.')),
      );
      return;
    }

    Navigator.of(context).pushNamed('/timetable');
  }

  /// Gérer la déconnexion
  Future<void> _handleLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Déconnexion'),
        content: const Text('Êtes-vous sûr de vouloir vous déconnecter?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authProvider = context.read<AuthProvider>();
      await authProvider.logout();

      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }
}
