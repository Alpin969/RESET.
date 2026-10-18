import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'repositories/auth_repository.dart';

const resetGreen = Color(0xFF22966B);
const resetDark = Color(0xFF183B2C);
const resetBackground = Color(0xFFF7FAF8);
const resetBorder = Color(0xFFE5ECE7);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (url.isNotEmpty && key.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: key);
    runApp(const ResetApp(configured: true));
  } else {
    runApp(const ResetApp(configured: false));
  }
}

class ResetApp extends StatelessWidget {
  final bool configured;

  const ResetApp({super.key, required this.configured});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RESET.',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: resetBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: resetGreen,
          primary: resetGreen,
          surface: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF9FBFA),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: resetBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: resetBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: resetGreen, width: 1.5),
          ),
        ),
      ),
      home: configured ? const AuthGate() : const SetupPage(),
    );
  }
}

class ResetLogo extends StatelessWidget {
  final double size;

  const ResetLogo({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE4F5EB),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(Icons.eco_rounded, color: resetGreen, size: size * 0.6),
    );
  }
}

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 460),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: resetBorder),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ResetLogo(size: 64),
              SizedBox(height: 20),
              Text(
                'RESET.',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: resetDark,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Supabase belum dikonfigurasi.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Text(
                'Jalankan Flutter menggunakan SUPABASE_URL dan SUPABASE_ANON_KEY.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Supabase.instance.client.auth;

    return StreamBuilder<AuthState>(
      stream: auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? auth.currentSession;

        if (session != null) {
          return const DashboardPage();
        }

        return const AuthPage();
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  bool register = false;
  bool loading = false;
  bool hidePassword = true;
  bool hideConfirm = true;

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> submit() async {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirm = confirmController.text;

    if (email.isEmpty || password.isEmpty) {
      showMessage('Email dan password wajib diisi.');
      return;
    }

    if (register) {
      if (username.isEmpty) {
        showMessage('Username wajib diisi.');
        return;
      }

      if (password.length < 6) {
        showMessage('Password minimal 6 karakter.');
        return;
      }

      if (password != confirm) {
        showMessage('Konfirmasi password tidak sama.');
        return;
      }
    }

    setState(() => loading = true);

    try {
      if (register) {
        final response = await authRepository.register(
          username: username,
          email: email,
          password: password,
          confirmPassword: confirm,
        );

        if (!mounted) return;

        if (response.session == null) {
          setState(() => register = false);
          showMessage(
            'Registrasi diterima. Cek email untuk verifikasi, lalu login.',
          );
        } else {
          showMessage('Akun berhasil dibuat.');
        }
      } else {
        await authRepository.signIn(email: email, password: password);
      }
    } on AuthException catch (error) {
      if (mounted) showMessage(error.message);
    } catch (error) {
      if (mounted) showMessage('Terjadi kesalahan: $error');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage('Isi email terlebih dahulu.');
      return;
    }

    try {
      await authRepository.sendPasswordReset(email);

      if (mounted) {
        showMessage('Jika email terdaftar, link pemulihan akan dikirim.');
      }
    } on AuthException catch (error) {
      if (mounted) showMessage(error.message);
    } catch (error) {
      if (mounted) showMessage('Gagal mengirim email: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;

          return Row(
            children: [
              if (desktop)
                Expanded(
                  child: Container(
                    color: const Color(0xFFEAF6EF),
                    padding: const EdgeInsets.all(60),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const ResetLogo(size: 72),
                            const SizedBox(height: 26),
                            const Text(
                              'Build better habits,\none day at a time.',
                              style: TextStyle(
                                color: resetDark,
                                fontSize: 40,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Atur kebiasaan, pantau perkembangan, dan terus berkembang bersama RESET.',
                              style: TextStyle(
                                color: resetDark.withValues(alpha: 0.7),
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!desktop) ...[
                            const ResetLogo(),
                            const SizedBox(height: 22),
                          ],
                          const Text(
                            'RESET.',
                            style: TextStyle(
                              color: resetDark,
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            register ? 'Create your account' : 'Welcome back!',
                            style: const TextStyle(
                              fontSize: 27,
                              color: resetDark,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            register
                                ? 'Start your journey with RESET.'
                                : 'Sign in to continue your progress.',
                            style: const TextStyle(color: Colors.black54),
                          ),
                          const SizedBox(height: 30),
                          if (register) ...[
                            fieldLabel('Username'),
                            TextField(
                              controller: usernameController,
                              decoration: const InputDecoration(
                                hintText: 'Your username',
                              ),
                            ),
                            const SizedBox(height: 18),
                          ],
                          fieldLabel('Email'),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'you@gmail.com',
                            ),
                          ),
                          const SizedBox(height: 18),
                          fieldLabel('Password'),
                          TextField(
                            controller: passwordController,
                            obscureText: hidePassword,
                            decoration: InputDecoration(
                              hintText: 'Enter password',
                              suffixIcon: IconButton(
                                onPressed: () {
                                  setState(() => hidePassword = !hidePassword);
                                },
                                icon: Icon(
                                  hidePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                              ),
                            ),
                          ),
                          if (register) ...[
                            const SizedBox(height: 18),
                            fieldLabel('Confirm password'),
                            TextField(
                              controller: confirmController,
                              obscureText: hideConfirm,
                              decoration: InputDecoration(
                                hintText: 'Confirm password',
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    setState(() => hideConfirm = !hideConfirm);
                                  },
                                  icon: Icon(
                                    hideConfirm
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                              ),
                            ),
                          ],
                          if (!register)
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: forgotPassword,
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: FilledButton(
                              onPressed: loading ? null : submit,
                              child: loading
                                  ? const SizedBox(
                                      width: 21,
                                      height: 21,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      register ? 'Create account' : 'Sign in',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              alignment: WrapAlignment.center,
                              children: [
                                Text(
                                  register
                                      ? 'Already have an account?'
                                      : "Don't have an account?",
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => register = !register);
                                  },
                                  child: Text(register ? 'Sign in' : 'Sign up'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Text(
        text,
        style: const TextStyle(color: resetDark, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int selectedPage = 0;

  final pages = const [
    'Dashboard',
    'My Tasks',
    'Sleep Tracker',
    'Savings',
    'Activity History',
    'Statistics',
    'Settings',
  ];

  final icons = const [
    Icons.grid_view_rounded,
    Icons.check_circle_outline_rounded,
    Icons.bedtime_outlined,
    Icons.account_balance_wallet_outlined,
    Icons.history_rounded,
    Icons.bar_chart_rounded,
    Icons.settings_outlined,
  ];

  String get username {
    final user = Supabase.instance.client.auth.currentUser;
    final value = user?.userMetadata?['username'];

    if (value is String && value.trim().isNotEmpty) {
      return value;
    }

    return user?.email?.split('@').first ?? 'User';
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;

        return Scaffold(
          drawer: desktop ? null : Drawer(child: sidebarContent()),
          body: Row(
            children: [
              if (desktop) SizedBox(width: 250, child: sidebarContent()),
              Expanded(
                child: Scaffold(
                  appBar: AppBar(
                    backgroundColor: resetBackground,
                    surfaceTintColor: Colors.transparent,
                    automaticallyImplyLeading: !desktop,
                    title: Text(
                      pages[selectedPage],
                      style: const TextStyle(
                        color: resetDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 20),
                        child: CircleAvatar(
                          backgroundColor: const Color(0xFFE4F5EB),
                          child: Text(
                            username.isEmpty ? 'U' : username[0].toUpperCase(),
                            style: const TextStyle(
                              color: resetGreen,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  body: selectedPage == 0
                      ? dashboardContent()
                      : Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icons[selectedPage],
                                size: 52,
                                color: resetGreen,
                              ),
                              const SizedBox(height: 15),
                              Text(
                                pages[selectedPage],
                                style: const TextStyle(
                                  fontSize: 23,
                                  fontWeight: FontWeight.w700,
                                  color: resetDark,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Halaman ini akan kita bangun berikutnya.',
                                style: TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: selectedPage < 4 ? selectedPage : 0,
                  onDestinationSelected: (index) {
                    setState(() => selectedPage = index);
                  },
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.check_circle_outline),
                      label: 'Tasks',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.bedtime_outlined),
                      label: 'Sleep',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      label: 'Savings',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget sidebarContent() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Row(
                children: [
                  ResetLogo(size: 43),
                  SizedBox(width: 12),
                  Text(
                    'RESET.',
                    style: TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: resetDark,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: pages.length,
                itemBuilder: (context, index) {
                  final active = selectedPage == index;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 3,
                    ),
                    child: ListTile(
                      leading: Icon(
                        icons[index],
                        color: active ? resetGreen : Colors.black54,
                      ),
                      title: Text(
                        pages[index],
                        style: TextStyle(
                          color: active ? resetGreen : resetDark,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      selected: active,
                      selectedTileColor: const Color(0xFFEAF6EF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () {
                        setState(() => selectedPage = index);
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 25),
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Logout'),
              onTap: () async {
                await authRepository.signOut();
              },
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }

  Widget dashboardContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1150),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Halo, $username 👋',
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: resetDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Small steps today, stronger habits tomorrow.',
                style: TextStyle(fontSize: 15, color: Colors.black54),
              ),
              const SizedBox(height: 26),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 600;

                  final cards = [
                    summaryCard(
                      Icons.local_fire_department_rounded,
                      'Current Streak',
                      '0 days',
                    ),
                    summaryCard(
                      Icons.account_balance_wallet_outlined,
                      'Total Savings',
                      'Rp 0',
                    ),
                  ];

                  if (wide) {
                    return Row(
                      children: [
                        Expanded(child: cards[0]),
                        const SizedBox(width: 16),
                        Expanded(child: cards[1]),
                      ],
                    );
                  }

                  return Column(
                    children: [cards[0], const SizedBox(height: 16), cards[1]],
                  );
                },
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 800;

                  final tasks = contentCard(
                    'Daily Tasks',
                    Icons.check_circle_outline_rounded,
                    '0/0 selesai',
                    'Belum ada task. Nanti lu bisa membuat task sendiri.',
                  );

                  final sleep = contentCard(
                    'Sleep Tracker',
                    Icons.bedtime_outlined,
                    'Belum ada catatan',
                    'Nanti lu bisa memasukkan jam tidur dan jam bangun.',
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: tasks),
                        const SizedBox(width: 16),
                        Expanded(child: sleep),
                      ],
                    );
                  }

                  return Column(
                    children: [tasks, const SizedBox(height: 16), sleep],
                  );
                },
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: cardDecoration(),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Activity',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: resetDark,
                      ),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Grafik aktivitas akan tampil setelah task dan history terhubung.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    SizedBox(height: 30),
                    Icon(
                      Icons.bar_chart_rounded,
                      color: Color(0xFFB5DCC5),
                      size: 76,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget summaryCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(23),
      decoration: cardDecoration(),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEAF6EF),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: resetGreen, size: 25),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    color: resetDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget contentCard(
    String title,
    IconData icon,
    String value,
    String description,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: resetGreen),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: resetDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: resetDark,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    );
  }

  BoxDecoration cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: resetBorder),
    );
  }
}
