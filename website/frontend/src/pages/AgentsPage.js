import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './PageStyles.css';
import './AgentsPage.css';
import ParticlesBackground from '../components/ParticlesBackground';
import LoadingSpinner from '../components/LoadingSpinner';
import AgentCard from '../components/AgentCard';

const AgentsPage = () => {
  const [agents, setAgents] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [activeFilter, setActiveFilter] = useState('all');

  useEffect(() => {
    fetchAgents();
  }, []);

  const fetchAgents = async () => {
    try {
      setLoading(true);
      const response = await axios.get('/api/agents');
      setAgents(response.data);
      setError(null);
    } catch (err) {
      setError('Failed to load agents. Please try again.');
      console.error('Error fetching agents:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleActivateAgent = async (agentId) => {
    try {
      await axios.post(`/api/agents/${agentId}/activate`);
      // Update the agent status in the UI
      setAgents(agents.map(agent => 
        agent.id === agentId ? { ...agent, is_active: true } : agent
      ));
    } catch (err) {
      setError('Failed to activate agent. Please try again.');
      console.error('Error activating agent:', err);
    }
  };

  const handleDeactivateAgent = async (agentId) => {
    try {
      await axios.post(`/api/agents/${agentId}/deactivate`);
      // Update the agent status in the UI
      setAgents(agents.map(agent => 
        agent.id === agentId ? { ...agent, is_active: false } : agent
      ));
    } catch (err) {
      setError('Failed to deactivate agent. Please try again.');
      console.error('Error deactivating agent:', err);
    }
  };

  const filteredAgents = activeFilter === 'all' 
    ? agents 
    : agents.filter(agent => {
        if (activeFilter === 'active') return agent.is_active;
        if (activeFilter === 'inactive') return !agent.is_active;
        return agent.type === activeFilter;
      });

  // Group agents by category for display
  const agentGroups = {
    'Executive': filteredAgents.filter(a => ['CEO', 'CFO', 'CISO'].includes(a.type)),
    'Business': filteredAgents.filter(a => ['SALES', 'MARKETING', 'CUSTOMER_SERVICE', 'ACCOUNTING', 'FINANCE'].includes(a.type)),
    'Security': filteredAgents.filter(a => ['KQL_HUNTING', 'SECURITY_COPILOT', 'PURVIEW_GRC'].includes(a.type)),
    'System': filteredAgents.filter(a => ['ORCHESTRATOR'].includes(a.type)),
  };

  return (
    <>
      <div id="particles-js">
        <ParticlesBackground isAnimated={false} />
      </div>
      <div className="main">
        <div className="content-wrapper">
          <div className="page-header">
            <h1>AI Agents</h1>
            <div className="agent-filters">
              <button 
                className={activeFilter === 'all' ? 'active' : ''} 
                onClick={() => setActiveFilter('all')}
              >
                All Agents
              </button>
              <button 
                className={activeFilter === 'active' ? 'active' : ''} 
                onClick={() => setActiveFilter('active')}
              >
                Active
              </button>
              <button 
                className={activeFilter === 'inactive' ? 'active' : ''} 
                onClick={() => setActiveFilter('inactive')}
              >
                Inactive
              </button>
            </div>
          </div>

          {error && <div className="error-message">{error}</div>}
          
          {loading ? (
            <LoadingSpinner />
          ) : (
            <div className="agents-container">
              {Object.entries(agentGroups).map(([groupName, groupAgents]) => (
                groupAgents.length > 0 && (
                  <div key={groupName} className="agent-group">
                    <h2>{groupName} Agents</h2>
                    <div className="agent-grid">
                      {groupAgents.map(agent => (
                        <AgentCard 
                          key={agent.id}
                          agent={agent}
                          onActivate={() => handleActivateAgent(agent.id)}
                          onDeactivate={() => handleDeactivateAgent(agent.id)}
                        />
                      ))}
                    </div>
                  </div>
                )
              ))}
              
              {filteredAgents.length === 0 && (
                <div className="no-agents">
                  <p>No agents match the selected filter.</p>
                </div>
              )}
            </div>
          )}
        </div>
        <footer>&copy; 2025 ClarityXDR. All rights reserved.</footer>
      </div>
    </>
  );
};

export default AgentsPage;
