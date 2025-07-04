import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import './AgentCard.css';

const AgentCard = ({ agent, onActivate, onDeactivate }) => {
  const [isExpanded, setIsExpanded] = useState(false);
  const navigate = useNavigate();

  const handleViewDetails = () => {
    navigate(`/agents/${agent.id}`);
  };

  // Determine icon based on agent type
  const getAgentIcon = (type) => {
    const iconMap = {
      'CEO': 'fa-user-tie',
      'CFO': 'fa-chart-line',
      'CISO': 'fa-shield-alt',
      'SALES': 'fa-handshake',
      'MARKETING': 'fa-bullhorn',
      'CUSTOMER_SERVICE': 'fa-headset',
      'ACCOUNTING': 'fa-calculator',
      'FINANCE': 'fa-money-bill-wave',
      'KQL_HUNTING': 'fa-search',
      'SECURITY_COPILOT': 'fa-robot',
      'PURVIEW_GRC': 'fa-tasks',
      'ORCHESTRATOR': 'fa-sitemap'
    };
    
    return iconMap[type] || 'fa-cog';
  };

  // Determine color based on agent type
  const getAgentColor = (type) => {
    const colorMap = {
      'CEO': 'var(--teal)',
      'CFO': 'var(--teal)',
      'CISO': 'var(--orange)',
      'SALES': 'var(--lime)',
      'MARKETING': 'var(--lime)',
      'CUSTOMER_SERVICE': 'var(--lime)',
      'ACCOUNTING': 'var(--lime)',
      'FINANCE': 'var(--lime)',
      'KQL_HUNTING': 'var(--orange)',
      'SECURITY_COPILOT': 'var(--orange)',
      'PURVIEW_GRC': 'var(--orange)',
      'ORCHESTRATOR': 'var(--teal)'
    };
    
    return colorMap[type] || 'var(--white)';
  };

  return (
    <div className={`agent-card ${agent.is_active ? 'active' : 'inactive'}`}>
      <div className="agent-icon" style={{ color: getAgentColor(agent.type) }}>
        <i className={`fas ${getAgentIcon(agent.type)}`}></i>
      </div>
      <div className="agent-info">
        <h3>{agent.name}</h3>
        <span className="agent-type">{agent.type.replace('_', ' ')}</span>
        <p className="agent-description">{agent.description}</p>
        
        <div className={`agent-details ${isExpanded ? 'expanded' : ''}`}>
          <div className="agent-status">
            <span className={`status-indicator ${agent.is_active ? 'active' : 'inactive'}`}></span>
            <span>{agent.is_active ? 'Active' : 'Inactive'}</span>
          </div>
          
          {isExpanded && (
            <div className="agent-capabilities">
              <h4>Capabilities:</h4>
              <ul>
                {agent.capabilities && agent.capabilities.map((capability, index) => (
                  <li key={index}>{capability}</li>
                ))}
              </ul>
            </div>
          )}
        </div>
      </div>
      
      <div className="agent-actions">
        <button 
          className="btn-toggle-details" 
          onClick={() => setIsExpanded(!isExpanded)}
        >
          {isExpanded ? 'Show Less' : 'Show More'}
        </button>
        
        <button 
          className="btn-view-details"
          onClick={handleViewDetails}
        >
          Details
        </button>
        
        {agent.is_active ? (
          <button 
            className="btn-deactivate"
            onClick={onDeactivate}
          >
            Deactivate
          </button>
        ) : (
          <button 
            className="btn-activate"
            onClick={onActivate}
          >
            Activate
          </button>
        )}
      </div>
    </div>
  );
};

export default AgentCard;
