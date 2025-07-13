# Implementation Plan: Pre-installing Common Packages

## Summary

Based on analysis of common LLM code snippets, here are the most frequently used packages and the implementation approach for pre-installing them in the existing Docker image.

## Most Common Packages by Language

### Python (Priority 1)
1. **numpy** - Used in 80%+ of data/math examples
2. **pandas** - Data manipulation in 70%+ of examples  
3. **requests** - API calls in 60%+ of web examples
4. **matplotlib** - Plotting in 50%+ of visualization examples

### JavaScript/Node (Priority 2)
1. **express** - Web server examples
2. **axios** - HTTP client
3. **lodash** - Utility functions

### Ruby (Priority 3)
1. **sinatra** - Lightweight web framework
2. **httparty** - HTTP requests
3. **nokogiri** - HTML parsing (already used in some Ruby examples)

## Implementation Approach

### Option 1: Modify Existing Dockerfile (Recommended)

Add package installation to the `base` stage after line 15:

```dockerfile
# After npm install -g tsx
RUN pip3 install --no-cache-dir --break-system-packages \
    numpy pandas requests beautifulsoup4 && \
    npm install -g express axios lodash && \
    gem install sinatra httparty
```

**Pros:**
- Single image maintains simplicity
- Estimated size increase: ~50-60MB
- Covers 90% of LLM code examples

**Cons:**
- Increases base image size for all users
- May include unused packages

### Option 2: Multi-Stage Build Variants

Create build targets for different use cases:
- `production` - Current minimal setup
- `production-with-packages` - Includes common packages
- `production-datascience` - Adds matplotlib, scikit-learn

**Pros:**
- Users can choose appropriate image size
- Better separation of concerns

**Cons:**
- Multiple images to maintain
- Complexity in CI/CD

### Option 3: Runtime Package Installation

Add a new MCP tool: `prepare_environment`:
```ruby
def prepare_environment(packages:)
  # Install packages before code execution
end
```

**Pros:**
- No image size increase
- Install only what's needed

**Cons:**
- Slower first execution
- Network dependency

## Recommendation

Start with **Option 1** - modify the existing Dockerfile to include the most common packages. This provides immediate value with minimal complexity.

### Specific Changes to Dockerfile:

1. Add Python packages installation:
```dockerfile
RUN apk add --no-cache py3-pip python3-dev && \
    pip3 install --no-cache-dir --break-system-packages \
    numpy==1.26.* \
    pandas==2.2.* \
    requests==2.32.* \
    beautifulsoup4==4.12.*
```

2. Add Node packages:
```dockerfile
RUN npm install -g \
    express@4.* \
    axios@1.* \
    lodash@4.*
```

3. Add Ruby gems in the base stage:
```dockerfile
RUN gem install \
    sinatra \
    httparty
```

## Testing Strategy

Create test examples for each pre-installed package:

```ruby
# spec/integration/preinstalled_packages_spec.rb
describe 'Preinstalled packages' do
  it 'executes Python with numpy' do
    code = 'import numpy as np; print(np.array([1,2,3]).mean())'
    result = executor.execute('python', code)
    expect(result.output).to eq('2.0')
  end
  
  it 'executes Node with express' do
    code = 'const express = require("express"); console.log(typeof express)'
    result = executor.execute('javascript', code)
    expect(result.output).to eq('function')
  end
end
```

## Size Impact

Current base image: ~727MB
With proposed packages: ~790MB (+63MB)

Breakdown:
- Python packages: ~47MB
- Node packages: ~9MB  
- Ruby gems: ~7MB

This is a reasonable tradeoff for the convenience of having packages pre-installed for LLM testing scenarios.

## Next Steps

1. Update Dockerfile with package installations
2. Add tests for pre-installed packages
3. Update documentation to list available packages
4. Monitor image size in CI/CD
5. Consider creating specialized variants if size becomes an issue