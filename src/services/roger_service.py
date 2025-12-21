"""Roger service: builds personalized home content using the local AI provider.

This module wraps the existing AI service/provider to request structured
content for the home page: daily comic, parts tips/search terms, history
facts, Star Wars facts, weather summary, encouraging quote, and community
recommendations tuned to Parker (19, repairs retro PCs, likes Garfield,
history, Star Wars, high anxiety).
"""
from typing import Dict, Any, Optional
from services.ai_service import AIService
import logging

logger = logging.getLogger(__name__)


class RogerService:
    def __init__(self, ai_service: Optional[AIService] = None):
        self.ai = ai_service or AIService()

    async def build_home_content(self) -> Dict[str, Any]:
        """Return structured content for the home page.

        Uses the local AI provider if available; falls back to concise
        heuristics when not.
        """
        persona_note = (
            "You are Roger, a calm, encouraging, practical companion for Parker. "
            "Parker is 19 years old, repairs old PCs and laptops, loves Garfield comics, "
            "enjoys history and Star Wars, and has high anxiety. Keep replies brief, supportive, "
            "and give one small actionable step when appropriate. Return JSON with keys: "
            "garfield_url, parts_search_terms, parts_tips, history_fact, starwars_fact, "
            "weather_summary, positive_quote, subreddit_suggestions."
        )

        system_prompt = persona_note
        user_prompt = (
            "Please provide the following, in JSON only (no extra commentary):\n"
            "- garfield_url: a URL (or empty string) for today's Garfield comic image.\n"
            "- parts_search_terms: a short list of 3 search phrases to find spare parts for retro laptops/PCs.\n"
            "- parts_tips: 2 concise tips for finding compatible spare parts.\n"
            "- history_fact: one interesting history fact Parker may like (1-2 sentences).\n"
            "- starwars_fact: one Star Wars fact or trivia item (1-2 sentences).\n"
            "- weather_summary: include current summary and 'EXTREME' if severe, else normal.\n"
            "- positive_quote: one short encouraging psychology-based quote (<=2 lines).\n"
            "- jokes: list 3 dad jokes or light-hearted jokes (silly/retro PC themed if possible).\n"
            "- subreddit_suggestions: list 4 subreddits with a 1-line tip for how Parker could interact (be supportive).\n"
            "Return strictly valid JSON object with these keys."
        )

        try:
            # Build a single message for AIService.chat (it wraps provider chat and context)
            prompt = system_prompt + "\n\n" + user_prompt
            ai_result = await self.ai.chat(prompt, conversation_id=None, include_context=False)

            # ai_result expected to be a dict with 'success' and 'response'
            if isinstance(ai_result, dict):
                resp_text = ai_result.get('response') or ai_result.get('result') or ''
            else:
                resp_text = str(ai_result)

            import json
            try:
                parsed = json.loads(resp_text)
                return parsed
            except Exception:
                logger.warning("RogerService: AI returned non-JSON, falling back to heuristic content")

        except Exception as e:
            logger.exception("RogerService: AI call failed: %s", e)

        # Fallback heuristics
        return {
            "garfield_url": "",
            "parts_search_terms": ["laptop replacement keyboard vintage", "bios battery retro laptop", "30-pin IDE laptop hard drive replacement"],
            "parts_tips": ["Check model numbers on spare parts and verify pin counts.", "Search eBay/parts-focused subreddits and message sellers with a clear photo."],
            "history_fact": "On this day in history, an important event happened (fallback).",
            "starwars_fact": "A short Star Wars trivia fallback: the original trilogy began in 1977.",
            "weather_summary": "Weather service unavailable; try again later.",
            "positive_quote": "Small steps count — try one tiny fix today.",
            "jokes": [
                "Why did the computer go to school? Because it wanted to improve its bit!",
                "Why do Java developers wear glasses? Because they don't C#!",
                "How many programmers does it take to change a light bulb? None, that's a hardware problem!"
            ],
            "subreddit_suggestions": [
                {"subreddit": "r/VintageComputing", "tip": "Share photos of your repair progress and ask for parts advice."},
                {"subreddit": "r/techsupport", "tip": "Be concise, include specs and clear photos."},
                {"subreddit": "r/Garfield", "tip": "Post favorite strips and join lighthearted discussion."},
                {"subreddit": "r/history", "tip": "Ask for sources politely and reference dates."}
            ]
        }
