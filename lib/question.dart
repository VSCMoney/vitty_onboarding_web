import 'package:flutter/material.dart';

class QuestionsScreen extends StatefulWidget {
  final String userEmail;
  final VoidCallback onComplete;

  const QuestionsScreen({
    super.key,
    required this.userEmail,
    required this.onComplete,
  });

  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  final PageController _pageController = PageController();
  int _currentQuestion = 0;

  final Map<String, dynamic> _answers = {};

  final List<Question> _questions = [
    Question(
      id: 'travel_frequency',
      question: 'How often do you travel?',
      icon: Icons.flight_takeoff,
      gradient: const [Color(0xFF667EEA), Color(0xFF764BA2)],
      options: [
        QuestionOption(value: 'rarely', label: 'Rarely', emoji: '🏠'),
        QuestionOption(value: 'few_times', label: 'Few times a year', emoji: '✈️'),
        QuestionOption(value: 'monthly', label: 'Monthly', emoji: '🌍'),
        QuestionOption(value: 'frequent', label: 'Frequently', emoji: '🚀'),
      ],
    ),
    Question(
      id: 'travel_style',
      question: 'What\'s your travel style?',
      icon: Icons.style,
      gradient: const [Color(0xFFf093fb), Color(0xFFf5576c)],
      options: [
        QuestionOption(value: 'adventure', label: 'Adventure', emoji: '🏔️'),
        QuestionOption(value: 'relaxation', label: 'Relaxation', emoji: '🏖️'),
        QuestionOption(value: 'cultural', label: 'Cultural', emoji: '🕌'),
        QuestionOption(value: 'food', label: 'Food & Culinary', emoji: '🍛'),
      ],
    ),
    Question(
      id: 'budget',
      question: 'What\'s your typical budget?',
      icon: Icons.account_balance_wallet,
      gradient: const [Color(0xFF4facfe), Color(0xFF00f2fe)],
      options: [
        QuestionOption(value: 'budget', label: 'Budget', emoji: '💰'),
        QuestionOption(value: 'moderate', label: 'Moderate', emoji: '💳'),
        QuestionOption(value: 'luxury', label: 'Luxury', emoji: '💎'),
        QuestionOption(value: 'unlimited', label: 'Sky\'s the limit', emoji: '🌟'),
      ],
    ),
  ];

  void _selectOption(String questionId, String value) {
    setState(() {
      _answers[questionId] = value;
    });

    // Auto advance to next question after a short delay
    Future.delayed(const Duration(milliseconds: 400), () {
      if (_currentQuestion < _questions.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _handleComplete() {
    debugPrint('📝 User preferences: $_answers');
    // Here you can save answers to backend if needed
    widget.onComplete();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Questions PageView
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(), // Disable manual swipe
            onPageChanged: (index) {
              setState(() {
                _currentQuestion = index;
              });
            },
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              return _buildQuestionPage(_questions[index]);
            },
          ),

          // Progress bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Text(
                          'Question ${_currentQuestion + 1} of ${_questions.length}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          widget.userEmail,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  LinearProgressIndicator(
                    value: (_currentQuestion + 1) / _questions.length,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 4,
                  ),
                ],
              ),
            ),
          ),

          // Complete button (only on last question)
          if (_currentQuestion == _questions.length - 1 &&
              _answers[_questions[_currentQuestion].id] != null)
            Positioned(
              bottom: 40,
              left: 32,
              right: 32,
              child: SafeArea(
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _handleComplete,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _questions[_currentQuestion].gradient.first,
                      elevation: 8,
                      shadowColor: Colors.black26,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Complete Setup',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionPage(Question question) {
    final selectedValue = _answers[question.id];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: question.gradient,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 100, 24, 100),
          child: Column(
            children: [
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  question.icon,
                  size: 40,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),

              // Question
              Text(
                question.question,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              // Options
              Expanded(
                child: ListView.builder(
                  itemCount: question.options.length,
                  itemBuilder: (context, index) {
                    final option = question.options[index];
                    final isSelected = selectedValue == option.value;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _buildOptionCard(
                        option: option,
                        isSelected: isSelected,
                        onTap: () => _selectOption(question.id, option.value),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required QuestionOption option,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 200),
      tween: Tween(begin: 1.0, end: isSelected ? 1.05 : 1.0),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
                width: isSelected ? 3 : 2,
              ),
            ),
            child: Row(
              children: [
                // Emoji
                Text(
                  option.emoji,
                  style: const TextStyle(fontSize: 28),
                ),
                const SizedBox(width: 16),

                // Label
                Expanded(
                  child: Text(
                    option.label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.black87 : Colors.white,
                    ),
                  ),
                ),

                // Checkmark
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 28,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class Question {
  final String id;
  final String question;
  final IconData icon;
  final List<Color> gradient;
  final List<QuestionOption> options;

  Question({
    required this.id,
    required this.question,
    required this.icon,
    required this.gradient,
    required this.options,
  });
}

class QuestionOption {
  final String value;
  final String label;
  final String emoji;

  QuestionOption({
    required this.value,
    required this.label,
    required this.emoji,
  });
}