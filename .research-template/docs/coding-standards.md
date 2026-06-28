# Coding Standards
- Use tidyverse style with modern |> pipe
- Keep exploratory and analysis scripts in /scripts/
- Follow tidyverse principles for data manipulation
- Comment complex operations
- Final lines in statistical code should return objects, not print them
- Prefer wrapping reusable logic in functions, with clear arguments, instead of long sequences of top‑level statements and global variables.
- Each function should compute a single, clearly named result object and use that as the final expression (or a single return(result)), so it’s obvious what the function returns. If not using return(result), give a comment stating what it is returning.