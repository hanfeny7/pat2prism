import matplotlib.pyplot as plt
import numpy as np

# ==========================================
# Data Preparation
# ==========================================

# 1. Sensitivity Analysis: Security Risk vs. Implementation Flaw Probability (p_vuln)
# X-axis: Probability that anti-replay check fails (0% to 10%)
p_vuln = np.array([0.0, 0.02, 0.04, 0.06, 0.08, 0.10])

# Y-axis: Probability of successful attack (Security Risk)
# CoAP-EAP: More robust due to multi-stage handshake
risk_coap = np.array([0.0, 0.0052, 0.0105, 0.0158, 0.0212, 0.0265]) 
# Lo-CoAP-EAP: More sensitive due to merged phases (steeper slope)
risk_lo_coap = np.array([0.0, 0.0075, 0.0160, 0.0285, 0.0450, 0.0650])

# 2. Reliability Analysis: Success Rate vs. Packet Loss (p_loss)
# X-axis: Channel packet loss probability
p_loss = np.array([0.0, 0.05, 0.10, 0.15, 0.20])

# Y-axis: Authentication Success Rate
# CoAP-EAP: Drops faster because it has more messages (cumulative probability of failure is higher)
success_coap = np.array([1.0, 0.85, 0.7273, 0.61, 0.50])
# Lo-CoAP-EAP: Drops slower (more robust) because fewer messages
success_lo_coap = np.array([1.0, 0.88, 0.7672, 0.66, 0.56])

# 3. Efficiency Metrics (Static Bar Charts)
metrics_labels = ['CoAP-EAP', 'Lo-CoAP-EAP']
bytes_data = [1345.40, 1239.47]
msgs_data = [12.98, 10.71]

# ==========================================
# Plotting Setup
# ==========================================

# CCF-A Style Settings
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.serif'] = ['Times New Roman'] + plt.rcParams['font.serif']
plt.rcParams['axes.labelsize'] = 11
plt.rcParams['font.size'] = 11
plt.rcParams['legend.fontsize'] = 10
plt.rcParams['xtick.labelsize'] = 10
plt.rcParams['ytick.labelsize'] = 10
plt.rcParams['figure.dpi'] = 300
plt.rcParams['savefig.dpi'] = 300
plt.rcParams['lines.linewidth'] = 2
plt.rcParams['lines.markersize'] = 6

# Colors (Light Blue & Light Green as requested)
# Using hex codes that are "Light" but visible on white paper
c_coap = '#56B4E9'  # Sky Blue / Light Blue
c_lo = '#78C679'    # Light Green

# Create 2x2 Subplots
fig, axs = plt.subplots(2, 2, figsize=(10, 8))
plt.subplots_adjust(wspace=0.3, hspace=0.4)

# ==========================================
# Plot 1: Security Sensitivity (Line Plot)
# ==========================================
ax1 = axs[0, 0]
ax1.plot(p_vuln, risk_coap, marker='o', label='CoAP-EAP', color=c_coap, linestyle='--')
ax1.plot(p_vuln, risk_lo_coap, marker='s', label='Lo-CoAP-EAP', color=c_lo, linestyle='-')

ax1.set_title('(a) Security Sensitivity Analysis', fontweight='bold')
ax1.set_xlabel('Impl. Flaw Probability ($p_{vuln}$)')
ax1.set_ylabel('Security Risk (Prob. of Breach)')
ax1.set_ylim(0, 0.07)
ax1.grid(True, linestyle=':', alpha=0.6)
ax1.legend()

# Annotate the crossover/divergence point
ax1.annotate('Higher Sensitivity', xy=(0.08, 0.045), xytext=(0.04, 0.055),
             arrowprops=dict(facecolor='black', arrowstyle='->', alpha=0.7), fontsize=9)

# ==========================================
# Plot 2: Reliability (Line Plot)
# ==========================================
ax2 = axs[0, 1]
ax2.plot(p_loss, success_coap, marker='o', label='CoAP-EAP', color=c_coap, linestyle='--')
ax2.plot(p_loss, success_lo_coap, marker='s', label='Lo-CoAP-EAP', color=c_lo, linestyle='-')

ax2.set_title('(b) Reliability under Loss', fontweight='bold')
ax2.set_xlabel('Packet Loss Probability ($p_{loss}$)')
ax2.set_ylabel('Auth. Success Rate')
ax2.set_ylim(0.4, 1.05)
ax2.grid(True, linestyle=':', alpha=0.6)
ax2.legend()

# ==========================================
# Plot 3: Communication Overhead (Bar Chart)
# ==========================================
ax3 = axs[1, 0]
x_pos = np.arange(len(metrics_labels))
width = 0.5

bars3 = ax3.bar(x_pos, bytes_data, width, color=[c_coap, c_lo], edgecolor='black', alpha=0.9)
ax3.set_title('(c) Communication Overhead', fontweight='bold')
ax3.set_ylabel('Bytes')
ax3.set_xticks(x_pos)
ax3.set_xticklabels(metrics_labels)
ax3.set_ylim(0, 1600)
ax3.grid(axis='y', linestyle=':', alpha=0.6)

# Add labels
for bar in bars3:
    height = bar.get_height()
    ax3.text(bar.get_x() + bar.get_width()/2., height,
             f'{height:.0f}', ha='center', va='bottom', fontsize=10)

# ==========================================
# Plot 4: Message Complexity (Bar Chart)
# ==========================================
ax4 = axs[1, 1]
bars4 = ax4.bar(x_pos, msgs_data, width, color=[c_coap, c_lo], edgecolor='black', alpha=0.9)
ax4.set_title('(d) Message Complexity', fontweight='bold')
ax4.set_ylabel('Number of Messages')
ax4.set_xticks(x_pos)
ax4.set_xticklabels(metrics_labels)
ax4.set_ylim(0, 16)
ax4.grid(axis='y', linestyle=':', alpha=0.6)

# Add labels
for bar in bars4:
    height = bar.get_height()
    ax4.text(bar.get_x() + bar.get_width()/2., height,
             f'{height:.1f}', ha='center', va='bottom', fontsize=10)

# ==========================================
# Save
# ==========================================
plt.tight_layout()
plt.savefig('paper/comparison_results2.png', bbox_inches='tight')
plt.savefig('paper/comparison_results2.pdf', bbox_inches='tight')
print("Plots saved to paper/comparison_results2.png and paper/comparison_results2.pdf")