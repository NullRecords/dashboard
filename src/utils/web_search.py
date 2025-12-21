#!/usr/bin/env python3
"""
Web search utilities for Roger AI assistant.
Provides internet research capabilities using DuckDuckGo (no API key needed).
"""

import logging
import requests
from typing import List, Dict, Any, Optional
from urllib.parse import quote_plus
import re

logger = logging.getLogger(__name__)


def search_web(query: str, max_results: int = 5) -> List[Dict[str, str]]:
    """
    Search the web using DuckDuckGo Lite.
    No API key required.
    
    Args:
        query: Search query string
        max_results: Maximum number of results to return
        
    Returns:
        List of search results with title, url, and snippet
    """
    try:
        # Use DuckDuckGo Lite which is simpler to parse
        url = f"https://lite.duckduckgo.com/lite/?q={quote_plus(query)}"
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        
        results = []
        html = response.text
        
        # Parse results - DuckDuckGo Lite has simpler HTML
        # Results are in table rows with class="result-link"
        link_pattern = r'<a[^>]*rel="nofollow"[^>]*href="([^"]+)"[^>]*>([^<]+)</a>'
        snippet_pattern = r'<td[^>]*class="result-snippet"[^>]*>([^<]+)</td>'
        
        links = re.findall(link_pattern, html)
        snippets = re.findall(snippet_pattern, html)
        
        # If that didn't work, try alternate patterns
        if not links:
            # Try to find any external links
            link_pattern2 = r'href="(https?://(?!duckduckgo)[^"]+)"[^>]*>([^<]+)</a>'
            links = re.findall(link_pattern2, html)
        
        for i, (link, title) in enumerate(links[:max_results]):
            if 'duckduckgo.com' in link:
                continue
            result = {
                'title': title.strip(),
                'url': link,
                'snippet': snippets[i].strip() if i < len(snippets) else ''
            }
            results.append(result)
        
        logger.info(f"Web search for '{query}' returned {len(results)} results")
        return results
        
    except Exception as e:
        logger.error(f"Web search error: {e}")
        return []


def fetch_page_summary(url: str, max_chars: int = 2000) -> Optional[str]:
    """
    Fetch and extract main text content from a webpage.
    
    Args:
        url: URL to fetch
        max_chars: Maximum characters to return
        
    Returns:
        Extracted text content or None on error
    """
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        }
        
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        
        html = response.text
        
        # Remove script and style elements
        html = re.sub(r'<script[^>]*>.*?</script>', '', html, flags=re.DOTALL | re.IGNORECASE)
        html = re.sub(r'<style[^>]*>.*?</style>', '', html, flags=re.DOTALL | re.IGNORECASE)
        
        # Remove HTML tags
        text = re.sub(r'<[^>]+>', ' ', html)
        
        # Clean up whitespace
        text = re.sub(r'\s+', ' ', text).strip()
        
        # Decode HTML entities
        text = text.replace('&nbsp;', ' ')
        text = text.replace('&amp;', '&')
        text = text.replace('&lt;', '<')
        text = text.replace('&gt;', '>')
        text = text.replace('&quot;', '"')
        
        return text[:max_chars] if text else None
        
    except Exception as e:
        logger.error(f"Error fetching page {url}: {e}")
        return None


def search_and_summarize(query: str, max_results: int = 3) -> Dict[str, Any]:
    """
    Search the web and return summarized results.
    
    Args:
        query: Search query
        max_results: Number of results to fetch and summarize
        
    Returns:
        Dict with search results and summaries
    """
    results = search_web(query, max_results)
    
    summaries = []
    for result in results:
        summary = {
            'title': result['title'],
            'url': result['url'],
            'snippet': result['snippet'],
            'content': None
        }
        
        # Optionally fetch full content (can be slow)
        # content = fetch_page_summary(result['url'])
        # if content:
        #     summary['content'] = content
        
        summaries.append(summary)
    
    return {
        'query': query,
        'results': summaries,
        'count': len(summaries)
    }


def quick_answer(query: str) -> Optional[str]:
    """
    Try to get a quick answer using DuckDuckGo Instant Answer API.
    Good for simple facts, definitions, calculations.
    
    Args:
        query: Question or search term
        
    Returns:
        Quick answer text or None
    """
    try:
        url = f"https://api.duckduckgo.com/?q={quote_plus(query)}&format=json&no_html=1"
        
        response = requests.get(url, timeout=5)
        response.raise_for_status()
        
        data = response.json()
        
        # Check different answer types
        if data.get('Answer'):
            return data['Answer']
        
        if data.get('AbstractText'):
            return data['AbstractText']
        
        if data.get('Definition'):
            return data['Definition']
        
        # Check for instant answer
        if data.get('Infobox') and data['Infobox'].get('content'):
            content = data['Infobox']['content']
            if isinstance(content, list) and content:
                answers = [f"{item.get('label', '')}: {item.get('value', '')}" 
                          for item in content[:3] if item.get('value')]
                if answers:
                    return '\n'.join(answers)
        
        return None
        
    except Exception as e:
        logger.debug(f"Quick answer failed: {e}")
        return None


# Convenience functions
def research(topic: str) -> str:
    """
    Research a topic and return formatted results.
    Combines quick answers with web search.
    
    Args:
        topic: Topic to research
        
    Returns:
        Formatted research results
    """
    parts = []
    
    # Try quick answer first
    quick = quick_answer(topic)
    if quick:
        parts.append(f"**Quick Answer:**\n{quick}\n")
    
    # Then do web search
    search_results = search_web(topic, max_results=5)
    if search_results:
        parts.append("**Web Results:**")
        for i, result in enumerate(search_results, 1):
            parts.append(f"{i}. [{result['title']}]({result['url']})")
            if result.get('snippet'):
                parts.append(f"   {result['snippet']}")
    
    if not parts:
        return f"No results found for: {topic}"
    
    return '\n'.join(parts)
