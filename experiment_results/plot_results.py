import matplotlib.pyplot as plt
import numpy as np

# Data
protocols = ['CoAP-EAP', 'LO-CoAP-EAP']
success_rate = [0.7273, 0.7672]
security_risk = [0.0131, 0.0186]
avg_bytes = [1345.40, 1239.47]
avg_msgs = [12.98, 10.71]

# Setup for CCF-A style plots
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Times New Roman'] + plt.rcParams['font.serif']
plt.rcParams['axes.labelsize'] = 12
plt.rcParams['font.size'] = 12
plt.rcParams['legend.fontsize'] = 10
plt.rcParams['xtick.labelsize'] = 10
plt.rcParams['ytick.labelsize'] = 10
plt.rcParams['figure.dpi'] = 300
plt.rcParams['savefig.dpi'] = 300

# Colors (Professional/Academic palette)
colors = ['#4E79A7', '#F28E2B']  # Tableau-like Blue and Orange

def plot_metric(ax, data, title, ylabel, y_limit=None, is_percentage=False):
    x = np.arange(len(protocols))
    width = 0.5
    
    bars = ax.bar(x, data, width, color=colors, edgecolor='black', linewidth=1, alpha=0.9)
    
    # Add value labels on top
    for bar in bars:
        height = bar.get_height()
        if is_percentage:
            label = f'{height:.2%}'
        else:
            label = f'{height:.2f}'
        ax.text(bar.get_x() + bar.get_width()/2., height,
                label,
                ha='center', va='bottom', fontsize=10, fontweight='bold')
    
    ax.set_ylabel(ylabel, fontweight='bold')
    ax.set_title(title, fontweight='bold', pad=15)
    ax.set_xticks(x)
    ax.set_xticklabels(protocols)
    ax.grid(axis='y', linestyle='--', alpha=0.5)
    
    if y_limit:
        ax.set_ylim(0, y_limit)
    else:
        ax.set_ylim(0, max(data) * 1.2)

# Create 2x2 Subplots
fig, axs = plt.subplots(2, 2, figsize=(10, 8))
plt.subplots_adjust(wspace=0.3, hspace=0.4)

# Plot 1: Success Rate
plot_metric(axs[0, 0], success_rate, 'Authentication Success Rate', 'Probability', y_limit=1.0, is_percentage=True)

# Plot 2: Security Risk
plot_metric(axs[0, 1], security_risk, 'Security Risk (Compromise)', 'Probability', y_limit=0.03, is_percentage=True)

# Plot 3: Average Overhead
plot_metric(axs[1, 0], avg_bytes, 'Communication Overhead', 'Bytes', y_limit=1600)

# Plot 4: Average Messages
plot_metric(axs[1, 1], avg_msgs, 'Message Complexity', 'Number of Messages', y_limit=16)

# Save
plt.tight_layout()
plt.savefig('comparison_results.png', bbox_inches='tight')
plt.savefig('comparison_results.pdf', bbox_inches='tight')
print("Plots saved to comparison_results.png and comparison_results.pdf")
