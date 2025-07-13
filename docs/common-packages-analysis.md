# Common Packages Analysis for LLM Code Execution

## Overview
This analysis identifies the most frequently used packages in LLM-generated code snippets across different programming languages. The goal is to pre-install these packages to enable immediate execution without runtime installation.

## Python Packages

### Data Science & Analysis (Most Common)
- **numpy** - Numerical computing, arrays, linear algebra
- **pandas** - Data manipulation, CSV/Excel handling
- **matplotlib** - Basic plotting and visualization
- **requests** - HTTP requests, API interactions
- **json** (built-in) - JSON parsing

### Machine Learning & AI
- **scikit-learn** - Basic ML algorithms, data preprocessing
- **tensorflow** or **torch** - Neural networks (choose one to limit size)
- **transformers** - NLP tasks, pre-trained models

### Web & APIs
- **flask** - Simple web servers, REST APIs
- **beautifulsoup4** - Web scraping
- **selenium** - Browser automation

### Utilities
- **datetime** (built-in) - Date/time manipulation
- **re** (built-in) - Regular expressions
- **os**, **sys** (built-in) - System operations
- **math** (built-in) - Mathematical operations
- **random** (built-in) - Random number generation
- **itertools** (built-in) - Iteration tools
- **collections** (built-in) - Specialized containers

### File Processing
- **csv** (built-in) - CSV file handling
- **openpyxl** - Excel file manipulation
- **pillow** - Image processing

## JavaScript/Node Packages

### Core Web Development
- **express** - Web framework
- **axios** - HTTP client
- **lodash** - Utility functions
- **moment** - Date manipulation

### Data Processing
- **csv-parse** - CSV parsing
- **xlsx** - Excel file handling

### Testing & Validation
- **jest** - Testing framework
- **joi** - Data validation

### Database
- **mongodb** - MongoDB driver
- **pg** - PostgreSQL driver

### Utilities
- **fs** (built-in) - File system
- **path** (built-in) - Path manipulation
- **crypto** (built-in) - Cryptography
- **http/https** (built-in) - HTTP operations

## Ruby Gems

### Web Development
- **sinatra** - Lightweight web framework
- **httparty** - HTTP requests
- **nokogiri** - HTML/XML parsing

### Data Processing
- **csv** (built-in) - CSV handling
- **json** (built-in) - JSON parsing

### Database
- **sqlite3** - SQLite database
- **pg** - PostgreSQL driver

### Testing
- **rspec** - Testing framework (already included)

### Utilities
- **date** (built-in) - Date handling
- **fileutils** (built-in) - File operations
- **open-uri** (built-in) - URL opening

## Size Impact Analysis

### Current Base Image Sizes
- Alpine Ruby base: ~50MB
- Python slim base: ~150MB
- Node slim base: ~180MB

### Estimated Package Sizes

#### Python Scientific Stack
- numpy: ~15MB
- pandas: ~30MB
- matplotlib: ~40MB
- scikit-learn: ~25MB
- **Total: ~110MB**

#### Minimal Python Stack
- numpy: ~15MB
- pandas: ~30MB
- requests: ~1MB
- beautifulsoup4: ~0.5MB
- **Total: ~47MB**

#### Node.js Common Stack
- express: ~0.5MB
- axios: ~0.5MB
- lodash: ~5MB
- moment: ~3MB
- **Total: ~9MB**

#### Ruby Common Stack
- sinatra: ~2MB
- httparty: ~0.5MB
- nokogiri: ~10MB (with C extensions)
- **Total: ~13MB**

## Recommendations

### Tiered Approach

**Tier 1: Essential Packages (Minimal Size Impact)**
Pre-install in production image:

```dockerfile
# Python
RUN pip install --no-cache-dir \
    numpy==1.26.* \
    pandas==2.2.* \
    requests==2.32.* \
    beautifulsoup4==4.12.*

# Node.js
RUN npm install -g \
    express@4.* \
    axios@1.* \
    lodash@4.*

# Ruby (already has most built-ins)
RUN gem install \
    sinatra \
    httparty
```

**Tier 2: Data Science Focus (Separate Image)**
Create `code-sandbox:datascience` variant:

```dockerfile
FROM code-sandbox:latest
RUN pip install --no-cache-dir \
    matplotlib==3.9.* \
    scikit-learn==1.5.* \
    seaborn==0.13.* \
    plotly==5.22.*
```

### Implementation Strategy

1. **Multi-stage Caching**
   - Cache pip/npm/gem downloads in builder stage
   - Copy only installed packages to production

2. **Version Pinning**
   - Pin major versions for stability
   - Allow minor/patch updates for security

3. **Size Optimization**
   - Use `--no-cache-dir` for pip
   - Clean up after installation
   - Consider Alpine-compatible wheels

4. **Testing**
   - Add tests for each pre-installed package
   - Verify import/require statements work
   - Check for version conflicts

## Usage Patterns

### Common LLM Code Examples

**Python Data Analysis:**
```python
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt

# Read data
df = pd.read_csv('data.csv')
# Process
result = df.groupby('category').mean()
# Visualize
plt.plot(result)
```

**Web Scraping:**
```python
import requests
from bs4 import BeautifulSoup

response = requests.get('https://example.com')
soup = BeautifulSoup(response.text, 'html.parser')
```

**API Server:**
```javascript
const express = require('express');
const app = express();

app.get('/', (req, res) => {
  res.json({ message: 'Hello World' });
});
```

These patterns justify the recommended package selections.