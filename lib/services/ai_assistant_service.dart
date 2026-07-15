import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smartchama/models/ai_chat_model.dart';

class AIAssistantService {
  static final AIAssistantService _instance = AIAssistantService._internal();
  factory AIAssistantService() => _instance;
  AIAssistantService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference get _chats => _firestore.collection('ai_chats');

  Future<String> getResponse(String message, String chamaId, String userId) async {
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('save') || lowerMessage.contains('saving') || lowerMessage.contains('savings')) {
      return _getSavingsAdvice(chamaId, userId);
    } else if (lowerMessage.contains('loan') || lowerMessage.contains('borrow') || lowerMessage.contains('debt')) {
      return _getLoanAdvice(chamaId, userId);
    } else if (lowerMessage.contains('invest') || lowerMessage.contains('investment')) {
      return _getInvestmentAdvice(chamaId, userId);
    } else if (lowerMessage.contains('budget') || lowerMessage.contains('expense') || lowerMessage.contains('expenses')) {
      return _getBudgetAdvice(chamaId, userId);
    } else if (lowerMessage.contains('contribution') || lowerMessage.contains('contribute')) {
      return _getContributionAdvice(chamaId, userId);
    } else if (lowerMessage.contains('report') || lowerMessage.contains('summary') || lowerMessage.contains('overview')) {
      return _getFinancialSummary(chamaId, userId);
    } else {
      return _getGeneralAdvice(chamaId, userId);
    }
  }

  Future<String> _getSavingsAdvice(String chamaId, String userId) async {
    final contributions = await _getUserContributions(chamaId, userId);
    final total = contributions.fold(0.0, (sum, c) => sum + c['amount']);
    
    if (total > 50000) {
      return "Great job! Your total contributions of KES ${total.toInt()} show excellent savings discipline. Consider increasing your monthly contributions by 10-20% to accelerate wealth building. You're on track for strong financial growth!";
    } else if (total > 20000) {
      return "You're building a solid savings foundation with KES ${total.toInt()} in contributions. Try setting up automatic monthly contributions and aim for 20% of your income. Consistency is key to reaching your financial goals.";
    } else if (total > 0) {
      return "Every contribution counts! You've saved KES ${total.toInt()} so far. To improve: 1) Set a monthly savings target, 2) Track every shilling, 3) Cut unnecessary expenses, 4) Increase contributions gradually. Small steps lead to big results!";
    } else {
      return "Start your savings journey today! Even small, regular contributions build wealth over time. Consider these tips: 1) Save at least 10% of income, 2) Use the 50/30/20 rule, 3) Track expenses, 4) Set up automatic transfers. Your future self will thank you!";
    }
  }

  Future<String> _getLoanAdvice(String chamaId, String userId) async {
    final loans = await _getUserLoans(chamaId, userId);
    final totalLoans = loans.fold(0.0, (sum, l) => sum + (l['amount'] ?? 0.0));
    final totalRepaid = loans.fold(0.0, (sum, l) => sum + (l['repaidAmount'] ?? 0.0));
    final outstanding = totalLoans - totalRepaid;

    if (outstanding > 0) {
      return "You currently have KES ${outstanding.toInt()} in outstanding loans. Recommendation: 1) Prioritize high-interest loan repayment, 2) Consider consolidating multiple loans, 3) Only borrow what you truly need, 4) Maintain a good repayment record. Your repayment history directly impacts your creditworthiness within the chama.";
    } else {
      return "Smart borrowing can accelerate your goals! Before taking a loan: 1) Ensure you can afford repayments, 2) Compare interest rates, 3) Use loans for income-generating activities, 4) Keep loan-to-income ratio below 30%. Remember: loans build wealth when used wisely.";
    }
  }

  Future<String> _getInvestmentAdvice(String chamaId, String userId) async {
    return "Diversify your investments for better returns! Consider these options within your chama:\n\n1. Treasury Bills - Low risk, stable returns (7-12% p.a.)\n2. Money Market Funds - Liquid, low risk\n3. SACCO Shares - Higher returns, community-focused\n4. Fixed Deposits - Guaranteed returns\n\nTip: Start with low-risk investments and gradually diversify. Always invest money you won't need immediately. The key is balancing risk and reward based on your financial goals.";
  }

  Future<String> _getBudgetAdvice(String chamaId, String userId) async {
    return "Master your budget with the 50/30/20 rule:\n\n50% - Needs (rent, food, transport)\n30% - Wants (entertainment, dining out)\n20% - Savings & Investments\n\nAdditional tips:\n- Track all expenses for 30 days\n- Cut unnecessary subscriptions\n- Cook at home more often\n- Use public transport when possible\n- Negotiate better rates on utilities\n\nA budget is not a restriction - it's freedom! Knowing where your money goes gives you control over your financial future.";
  }

  Future<String> _getContributionAdvice(String chamaId, String userId) async {
    final contributions = await _getUserContributions(chamaId, userId);
    final total = contributions.fold(0.0, (sum, c) => sum + c['amount']);
    
    return "Maximize your chama contributions! Benefits of consistent contributions:\n\n1. Builds emergency fund\n2. Access to group loans at lower rates\n3. Collective investment power\n4. Financial discipline\n5. Community support\n\nRecommendation: Contribute at least 10-20% of your monthly income. Consider increasing contributions during high-income months. Your consistent contributions make the chama stronger for everyone!";
  }

  Future<String> _getFinancialSummary(String chamaId, String userId) async {
    final contributions = await _getUserContributions(chamaId, userId);
    final loans = await _getUserLoans(chamaId, userId);
    
    final totalContributions = contributions.fold(0.0, (sum, c) => sum + c['amount']);
    final totalLoans = loans.fold(0.0, (sum, l) => sum + (l['amount'] ?? 0.0));
    final totalRepaid = loans.fold(0.0, (sum, l) => sum + (l['repaidAmount'] ?? 0.0));
    final netWorth = totalContributions - totalLoans;
    
    return "Your Financial Summary:\n\nTotal Contributions: KES ${totalContributions.toInt()}\nTotal Loans: KES ${totalLoans.toInt()}\nTotal Repaid: KES ${totalRepaid.toInt()}\nNet Position: KES ${netWorth.toInt()}\n\n${netWorth > 0 ? 'Great financial health!' : 'Focus on reducing debt while maintaining contributions.'} Keep tracking your progress and stay committed to your financial goals!";
  }

  Future<String> _getGeneralAdvice(String chamaId, String userId) async {
    return "Welcome to your AI Financial Assistant! I'm here to help you with:\n\n- Savings strategies\n- Loan advice\n- Investment guidance\n- Budgeting tips\n- Contribution optimization\n- Financial summaries\n\nJust ask me anything about personal finance or your chama finances. I'll provide personalized advice based on your financial data. How can I help you today?";
  }

  Future<List<Map<String, dynamic>>> _getUserContributions(String chamaId, String userId) async {
    final snapshot = await _firestore
        .collection("organizations")
        .doc(chamaId)
        .collection("chamas")
        .doc(chamaId)
        .collection("contributions")
        .where("userId", isEqualTo: userId)
        .get();
    
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<Map<String, dynamic>>> _getUserLoans(String chamaId, String userId) async {
    final snapshot = await _firestore
        .collection("organizations")
        .doc(chamaId)
        .collection("chamas")
        .doc(chamaId)
        .collection("loans")
        .where("userId", isEqualTo: userId)
        .get();
    
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> saveChatMessage(AIChatMessage message) async {
    final doc = _chats.doc();
    await doc.set(message.toMap());
  }

  Future<List<AIChatMessage>> getChatHistory(String chamaId, String userId, {int limit = 50}) async {
    final snapshot = await _chats
        .where('chamaId', isEqualTo: chamaId)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .get();

    return snapshot.docs
        .map((doc) => AIChatMessage.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();
  }

  List<AISuggestion> getDefaultSuggestions() {
    return [
      AISuggestion(id: '1', text: 'How can I save more?', category: 'savings'),
      AISuggestion(id: '2', text: 'Should I take a loan?', category: 'loans'),
      AISuggestion(id: '3', text: 'Investment tips', category: 'investments'),
      AISuggestion(id: '4', text: 'Show my financial summary', category: 'general'),
      AISuggestion(id: '5', text: 'Budget advice', category: 'budget'),
    ];
  }
}
