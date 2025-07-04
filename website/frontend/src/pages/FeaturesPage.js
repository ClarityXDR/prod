import React from 'react';
import ParticlesBackground from '../components/ParticlesBackground';
import './PageStyles.css';

const FeaturesPage = () => {
  return (
    <>
      <div id="particles-js">
        <ParticlesBackground isAnimated={false} />
      </div>
      <div className="main">
        <div className="content-wrapper">
          <h1>Features</h1>
          
          <section className="feature-section">
            <h2>AI-Driven Security Operations</h2>
            <div className="feature-grid">
              <div className="feature-card">
                <h3>Advanced Threat Detection</h3>
                <p>Our AI agents continuously monitor your environment to detect anomalies and security threats in real-time.</p>
              </div>
              <div className="feature-card">
                <h3>Automated Response</h3>
                <p>When threats are detected, our system automatically takes appropriate remediation actions based on predefined playbooks.</p>
              </div>
              <div className="feature-card">
                <h3>KQL Powered Hunting</h3>
                <p>Our specialized AI agent leverages Kusto Query Language to hunt for threats across your Microsoft Defender environment.</p>
              </div>
              <div className="feature-card">
                <h3>24/7 Monitoring</h3>
                <p>Never sleep on security with our round-the-clock AI-driven monitoring and alert system.</p>
              </div>
            </div>
          </section>
          
          <section className="feature-section">
            <h2>GitHub-Integrated AI Agents</h2>
            <div className="feature-grid">
              <div className="feature-card">
                <h3>Mission Control Protocols</h3>
                <p>Each AI agent operates under strict Mission Control Protocol (MCP) guidelines to ensure responsible and focused behavior.</p>
              </div>
              <div className="feature-card">
                <h3>Issue-Based Workflow</h3>
                <p>AI agents automatically monitor and respond to GitHub Issues, creating an auditable trail of all AI decision-making.</p>
              </div>
              <div className="feature-card">
                <h3>Transparent Operations</h3>
                <p>All agent activities are documented in GitHub, providing complete visibility into AI operations and decisions.</p>
              </div>
              <div className="feature-card">
                <h3>Collaborative Intelligence</h3>
                <p>Multiple specialized agents work together through GitHub's collaboration features to solve complex problems.</p>
              </div>
            </div>
          </section>
          
          <section className="feature-section">
            <h2>Business Operations</h2>
            <div className="feature-grid">
              <div className="feature-card">
                <h3>Automated Sales</h3>
                <p>Our sales agent handles quotes, follows up with leads, and manages the entire sales pipeline through GitHub Issues.</p>
              </div>
              <div className="feature-card">
                <h3>Intelligent Invoicing</h3>
                <p>Automatic invoice generation, payment tracking, and service management for non-payment.</p>
              </div>
              <div className="feature-card">
                <h3>GitHub Issues Ticketing</h3>
                <p>AI-managed ticketing system that categorizes, prioritizes, and resolves customer issues through GitHub's native issue tracking.</p>
              </div>
              <div className="feature-card">
                <h3>Accounting Integration</h3>
                <p>Seamless integration with accounting systems for financial management and reporting.</p>
              </div>
            </div>
          </section>
        </div>
        <footer>&copy; 2025 ClarityXDR. All rights reserved.</footer>
      </div>
    </>
  );
};

export default FeaturesPage;
