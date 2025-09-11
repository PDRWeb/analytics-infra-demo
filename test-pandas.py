#!/usr/bin/env python3
"""
Simple test script to verify pandas import works correctly
"""

try:
    import pandas as pd
    import numpy as np
    print("✅ Pandas import successful!")
    print(f"Pandas version: {pd.__version__}")
    print(f"NumPy version: {np.__version__}")
    
    # Test basic pandas functionality
    df = pd.DataFrame({'test': [1, 2, 3]})
    print(f"✅ DataFrame creation successful: {df.shape}")
    
except ImportError as e:
    print(f"❌ Import error: {e}")
    exit(1)
except Exception as e:
    print(f"❌ Unexpected error: {e}")
    exit(1)

print("🎉 All pandas tests passed!")
