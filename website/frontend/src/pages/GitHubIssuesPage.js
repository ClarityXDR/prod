import React, { useState, useEffect } from 'react';
import axios from 'axios';
import { Link } from 'react-router-dom';
import './PageStyles.css';
import './GitHubIssuesPage.css';
import ParticlesBackground from '../components/ParticlesBackground';
import LoadingSpinner from '../components/LoadingSpinner';

const GitHubIssuesPage = () => {
  const [issues, setIssues] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [activeFilter, setActiveFilter] = useState('all');

  useEffect(() => {
    fetchIssues();
  }, []);

  const fetchIssues = async () => {
    try {
      setLoading(true);
      const response = await axios.get('/api/github/issues');
      setIssues(response.data);
      setError(null);
    } catch (err) {
      setError('Failed to load GitHub issues. Please try again.');
      console.error('Error fetching issues:', err);
    } finally {
      setLoading(false);
    }
  };

  const formatDate = (dateString) => {
    const date = new Date(dateString);
    return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
  };

  const filteredIssues = activeFilter === 'all' 
    ? issues 
    : issues.filter(issue => issue.status === activeFilter);

  return (
    <>
      <div id="particles-js">
        <ParticlesBackground isAnimated={false} />
      </div>
      <div className="main">
        <div className="content-wrapper">
          <div className="page-header">
            <h1>GitHub Issues</h1>
            <div className="issue-filters">
              <button 
                className={activeFilter === 'all' ? 'active' : ''} 
                onClick={() => setActiveFilter('all')}
              >
                All Issues
              </button>
              <button 
                className={activeFilter === 'open' ? 'active' : ''} 
                onClick={() => setActiveFilter('open')}
              >
                Open
              </button>
              <button 
                className={activeFilter === 'processing' ? 'active' : ''} 
                onClick={() => setActiveFilter('processing')}
              >
                Processing
              </button>
              <button 
                className={activeFilter === 'completed' ? 'active' : ''} 
                onClick={() => setActiveFilter('completed')}
              >
                Completed
              </button>
            </div>
          </div>

          <div className="github-header">
            <p>GitHub issues are automatically processed by AI agents according to their Mission Control Protocol (MCP) guidelines.</p>
            <a 
              href="https://github.com/ClarityXDR/issues/new" 
              target="_blank" 
              rel="noopener noreferrer"
              className="btn btn-primary"
            >
              Create New Issue
            </a>
          </div>

          {error && <div className="error-message">{error}</div>}
          
          {loading ? (
            <LoadingSpinner />
          ) : (
            <div className="github-issues-container">
              {filteredIssues.length > 0 ? (
                <table className="issues-table">
                  <thead>
                    <tr>
                      <th>Issue #</th>
                      <th>Title</th>
                      <th>Status</th>
                      <th>Agent</th>
                      <th>Created</th>
                      <th>Updated</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredIssues.map(issue => (
                      <tr key={issue.id} className={`status-${issue.status}`}>
                        <td>{issue.issue_number}</td>
                        <td className="issue-title">{issue.title}</td>
                        <td>
                          <span className={`status-badge ${issue.status}`}>
                            {issue.status}
                          </span>
                        </td>
                        <td>{issue.agent_name}</td>
                        <td>{formatDate(issue.created_at)}</td>
                        <td>{formatDate(issue.updated_at)}</td>
                        <td>
                          <div className="issue-actions">
                            <Link to={`/github-issues/${issue.id}`} className="btn btn-small">
                              View
                            </Link>
                            <a 
                              href={issue.url} 
                              target="_blank" 
                              rel="noopener noreferrer"
                              className="btn btn-small btn-secondary"
                            >
                              GitHub
                            </a>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <div className="no-issues">
                  <p>No GitHub issues match the selected filter.</p>
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

export default GitHubIssuesPage;
