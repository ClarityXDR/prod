import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import axios from 'axios';
import './PageStyles.css';
import './AgentDetailPage.css';
import ParticlesBackground from '../components/ParticlesBackground';
import LoadingSpinner from '../components/LoadingSpinner';

const AgentDetailPage = () => {
  const { agentId } = useParams();
  const navigate = useNavigate();
  const [agent, setAgent] = useState(null);
  const [actionLogs, setActionLogs] = useState([]);
  const [conversations, setConversations] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [activeTab, setActiveTab] = useState('overview');

  useEffect(() => {
    fetchAgentDetails();
  }, [agentId]);

  const fetchAgentDetails = async () => {
    try {
      setLoading(true);
      const [agentResponse, logsResponse, conversationsResponse] = await Promise.all([
        axios.get(`/api/agents/${agentId}`),
        axios.get(`/api/agents/${agentId}/logs`),
        axios.get(`/api/agents/${agentId}/conversations`)
      ]);
      
      setAgent(agentResponse.data);
      setActionLogs(logsResponse.data);
      setConversations(conversationsResponse.data);
      setError(null);
    } catch (err) {
      setError('Failed to load agent details. Please try again.');
      console.error('Error fetching agent details:', err);
    } finally {
      setLoading(false);
    }
  };

  const handleBackClick = () => {
    navigate('/agents');
  };

  const handleToggleActive = async () => {
    try {
      const endpoint = agent.is_active 
        ? `/api/agents/${agentId}/deactivate`
        : `/api/agents/${agentId}/activate`;
      
      await axios.post(endpoint);
      
      // Update the agent status in the UI
      setAgent({
        ...agent,
        is_active: !agent.is_active
      });
    } catch (err) {
      setError(`Failed to ${agent.is_active ? 'deactivate' : 'activate'} agent. Please try again.`);
      console.error('Error toggling agent status:', err);
    }
  };

  const formatTimestamp = (timestamp) => {
    return new Date(timestamp).toLocaleString();
  };

  if (loading) {
    return (
      <>
        <div id="particles-js">
          <ParticlesBackground isAnimated={false} />
        </div>
        <div className="main">
          <div className="content-wrapper">
            <LoadingSpinner />
          </div>
        </div>
      </>
    );
  }

  if (error || !agent) {
    return (
      <>
        <div id="particles-js">
          <ParticlesBackground isAnimated={false} />
        </div>
        <div className="main">
          <div className="content-wrapper">
            <div className="error-message">{error || 'Agent not found'}</div>
            <button className="btn btn-secondary" onClick={handleBackClick}>
              Back to Agents
            </button>
          </div>
        </div>
      </>
    );
  }

  return (
    <>
      <div id="particles-js">
        <ParticlesBackground isAnimated={false} />
      </div>
      <div className="main">
        <div className="content-wrapper">
          <div className="page-header">
            <button className="back-button" onClick={handleBackClick}>
              <i className="fas fa-arrow-left"></i> Back
            </button>
            <h1>{agent.name}</h1>
          </div>

          <div className="agent-detail-header">
            <div className="agent-status-badge">
              <span className={`status-indicator ${agent.is_active ? 'active' : 'inactive'}`}></span>
              <span>{agent.is_active ? 'Active' : 'Inactive'}</span>
            </div>
            
            <div className="agent-type-badge">
              {agent.type}
            </div>
            
            <button 
              className={`btn ${agent.is_active ? 'btn-warning' : 'btn-success'}`}
              onClick={handleToggleActive}
            >
              {agent.is_active ? 'Deactivate' : 'Activate'}
            </button>
          </div>

          <div className="agent-detail-tabs">
            <button 
              className={activeTab === 'overview' ? 'active' : ''}
              onClick={() => setActiveTab('overview')}
            >
              Overview
            </button>
            <button 
              className={activeTab === 'logs' ? 'active' : ''}
              onClick={() => setActiveTab('logs')}
            >
              Action Logs
            </button>
            <button 
              className={activeTab === 'conversations' ? 'active' : ''}
              onClick={() => setActiveTab('conversations')}
            >
              Conversations
            </button>
            <button 
              className={activeTab === 'settings' ? 'active' : ''}
              onClick={() => setActiveTab('settings')}
            >
              Settings
            </button>
          </div>

          {activeTab === 'overview' && (
            <div className="agent-overview">
              <div className="overview-section">
                <h3>Description</h3>
                <p>{agent.description}</p>
              </div>
              
              <div className="overview-section">
                <h3>Capabilities</h3>
                {agent.capabilities && agent.capabilities.length > 0 ? (
                  <ul className="capabilities-list">
                    {agent.capabilities.map((capability, index) => (
                      <li key={index}>{capability}</li>
                    ))}
                  </ul>
                ) : (
                  <p>No capabilities defined.</p>
                )}
              </div>
              
              <div className="overview-section">
                <h3>Recent Activity</h3>
                {actionLogs.length > 0 ? (
                  <div className="recent-activity">
                    {actionLogs.slice(0, 5).map(log => (
                      <div key={log.id} className="activity-item">
                        <div className="activity-icon">
                          <i className={`fas ${log.status === 'success' ? 'fa-check-circle' : 'fa-exclamation-circle'}`}></i>
                        </div>
                        <div className="activity-details">
                          <div className="activity-title">{log.action_type}</div>
                          <div className="activity-time">{formatTimestamp(log.created_at)}</div>
                          <div className="activity-status">{log.status}</div>
                        </div>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p>No recent activity.</p>
                )}
              </div>
            </div>
          )}

          {activeTab === 'logs' && (
            <div className="agent-logs">
              <h3>Action Logs</h3>
              {actionLogs.length > 0 ? (
                <table className="logs-table">
                  <thead>
                    <tr>
                      <th>Action Type</th>
                      <th>Status</th>
                      <th>Details</th>
                      <th>Time</th>
                    </tr>
                  </thead>
                  <tbody>
                    {actionLogs.map(log => (
                      <tr key={log.id} className={`log-status-${log.status}`}>
                        <td>{log.action_type}</td>
                        <td>{log.status}</td>
                        <td>{log.details ? JSON.stringify(log.details) : '-'}</td>
                        <td>{formatTimestamp(log.created_at)}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <p>No action logs found.</p>
              )}
            </div>
          )}

          {activeTab === 'conversations' && (
            <div className="agent-conversations">
              <h3>Conversations</h3>
              {conversations.length > 0 ? (
                <div className="conversations-list">
                  {conversations.map(conversation => (
                    <div key={conversation.id} className="conversation-item">
                      <div className="conversation-header">
                        <h4>{conversation.title || 'Untitled Conversation'}</h4>
                        <span className="conversation-time">{formatTimestamp(conversation.created_at)}</span>
                      </div>
                      <div className="conversation-metadata">
                        <span>Status: {conversation.status}</span>
                        <span>Messages: {conversation.message_count}</span>
                      </div>
                      <button className="btn btn-small" onClick={() => navigate(`/conversations/${conversation.id}`)}>
                        View Details
                      </button>
                    </div>
                  ))}
                </div>
              ) : (
                <p>No conversations found.</p>
              )}
            </div>
          )}

          {activeTab === 'settings' && (
            <div className="agent-settings">
              <h3>Agent Settings</h3>
              <div className="settings-form">
                <div className="form-group">
                  <label>Agent Name</label>
                  <input type="text" value={agent.name} readOnly />
                </div>
                
                <div className="form-group">
                  <label>Agent Type</label>
                  <input type="text" value={agent.type} readOnly />
                </div>
                
                <div className="form-group">
                  <label>Description</label>
                  <textarea value={agent.description} readOnly rows={4}></textarea>
                </div>
                
                <div className="form-group">
                  <label>Configuration</label>
                  <pre className="config-json">{JSON.stringify(agent.config || {}, null, 2)}</pre>
                </div>
                
                <p className="settings-note">Note: Agent settings are managed by the system administrator.</p>
              </div>
            </div>
          )}
        </div>
        <footer>&copy; 2025 ClarityXDR. All rights reserved.</footer>
      </div>
    </>
  );
};

export default AgentDetailPage;
