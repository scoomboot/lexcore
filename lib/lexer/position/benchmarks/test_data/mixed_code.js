// Complex source file with mixed content
const message = "Hello, 世界! 🌍"; // UTF-8 string
const regex = /[\u0000-\u001F]/g; // Control chars

/* Multi-line comment
 * with special chars: © ® ™
 * and emoji: 🔥 💯 ✅
 */

function calculate(α, β, γ) {
    const π = 3.14159;
    const result = α * Math.sin(β) + γ;
    console.log(`Result: ${result}°`);
    return result;
}

// Test data with tabs and spaces mixed
const data = {
    name: "Test",  // Tab replaced with spaces
    value: 42,     // Space indented
    emoji: "🚀"    // Tab replaced with spaces
};