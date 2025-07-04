import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './PageStyles.css';
import './KQLPage.css';
import ParticlesBackground from '../components/ParticlesBackground';
import LoadingSpinner from '../components/LoadingSpinner';
import { useParams } from 'react-router-dom';

const KQLPage = () => {
  const { clientId } = useParams();
  const [clients, setClients] = useState([]);
  const [selectedClient, setSelectedClient] = useState(clientId || '');
  const [query, setQuery] = useState('');
  const [queryResults, setQueryResults] = useState(null);
  const [isExecuting, setIsExecuting] = useState(false);
  const [error, setError] = useState(null);
  const [templates, setTemplates] = useState([]);
  const [selectedTemplate, setSelectedTemplate] = useState('');
  const [timeRange, setTimeRange] = useState('last24h');

  useEffect(() => {
    fetchClients();
    fetchQueryTemplates();
  }, []);

  useEffect(() => {
    if (selectedTemplate) {
      loadTemplateQuery(selectedTemplate);
    }
  }, [selectedTemplate]);

  const fetchClients = async () => {
    try {
      const response = await axios.get('/api/clients');
      setClients(response.data);
      
      // If clientId was passed in URL params, verify it exists
      if (clientId && response.data.some(client => client.id === clientId)) {
        setSelectedClient(clientId);
      } else if (response.data.length > 0) {
        setSelectedClient(response.data[0].id);
      }
    } catch (err) {
      setError('Failed to load clients. Please try again.');
      console.error('Error fetching clients:', err);
    }
  };

  const fetchQueryTemplates = async () => {
    try {
      const response = await axios.get('/api/kql/templates');
      setTemplates(response.data);
    } catch (err) {
      console.error('Error fetching query templates:', err);
    }
  };

  const loadTemplateQuery = async (templateId) => {
    try {
      const response = await axios.get(`/api/kql/templates/${templateId}`);
      setQuery(response.data.query_text);
    } catch (err) {
      setError('Failed to load template. Please try again.');
      console.error('Error loading template:', err);
    }
  };

  const executeQuery = async () => {
    if (!selectedClient || !query.trim()) {
      setError('Please select a client and enter a query.');
      return;
    }

    try {
      setIsExecuting(true);
      setError(null);
      
      const response = await axios.post('/api/kql/execute', {
        client_id: selectedClient,
        query: query,
        time_range: timeRange
      });
      
      setQueryResults(response.data);
    } catch (err) {
      setError('Failed to execute query. Please check your syntax and try again.');
      console.error('Error executing query:', err);
    } finally {
      setIsExecuting(false);
    }
  };

  const saveAsTemplate = async () => {
    if (!query.trim()) {
      setError('Please enter a query to save as template.');
      return;
    }

    try {
      const name = prompt('Enter a name for this template:');
      if (!name) return;

      const response = await axios.post('/api/kql/templates', {
        name,
        query_text: query,
        description: 'User created template',
        category: 'Custom'
      });

      setTemplates([...templates, response.data]);
      alert('Template saved successfully!');
    } catch (err) {
      setError('Failed to save template. Please try again.');
      console.error('Error saving template:', err);
    }
  };

  const formatResults = (results) => {
    if (!results || !results.tables || results.tables.length === 0) {
      return <p>No results found.</p>;
    }

    const table = results.tables[0];
    
    return (
      <div className="query-results-table">
        <div className="results-meta">
          <p>Found {table.rows.length} results in {results.execution_time_ms}ms</p>
        </div>
        <table>
          <thead>
            <tr>
              {table.columns.map((col, index) => (
                <th key={index}>{col.name}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {table.rows.map((row, rowIndex) => (
              <tr key={rowIndex}>
                {row.map((cell, cellIndex) => (
                  <td key={cellIndex}>{
                    typeof cell === 'object' ? JSON.stringify(cell) : cell
                  }</td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    );
  };

  return (
    <>
      <div id="particles-js">
        <ParticlesBackground isAnimated={false} />
      </div>
      <div className="main">
        <div className="content-wrapper">
          <h1>KQL Query Interface</h1>
          
          <div className="kql-container">
            <div className="kql-toolbar">
              <div className="toolbar-item">
                <label>Client:</label>
                <select 
                  value={selectedClient} 
                  onChange={(e) => setSelectedClient(e.target.value)}
                  disabled={isExecuting}
                >
                  <option value="">Select a client...</option>
                  {clients.map(client => (
                    <option key={client.id} value={client.id}>{client.name}</option>
                  ))}
                </select>
              </div>
              
              <div className="toolbar-item">
                <label>Template:</label>
                <select 
                  value={selectedTemplate} 
                  onChange={(e) => setSelectedTemplate(e.target.value)}
                  disabled={isExecuting}
                >
                  <option value="">Select a template...</option>
                  {templates.map(template => (
                    <option key={template.id} value={template.id}>{template.name}</option>
                  ))}
                </select>
              </div>
              
              <div className="toolbar-item">
                <label>Time Range:</label>
                <select 
                  value={timeRange} 
                  onChange={(e) => setTimeRange(e.target.value)}
                  disabled={isExecuting}
                >
                  <option value="last1h">Last 1 hour</option>
                  <option value="last24h">Last 24 hours</option>
                  <option value="last7d">Last 7 days</option>
                  <option value="last30d">Last 30 days</option>
                  <option value="custom">Custom</option>
                </select>
              </div>
            </div>
            
            <div className="kql-editor">
              <textarea
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Enter your KQL query here..."
                disabled={isExecuting}
                rows={10}
              />
            </div>
            
            <div className="kql-actions">
              <button 
                className="btn-run-query" 
                onClick={executeQuery}
                disabled={isExecuting || !selectedClient}
              >
                {isExecuting ? 'Executing...' : 'Run Query'}
              </button>
              
              <button 
                className="btn-save-template" 
                onClick={saveAsTemplate}
                disabled={isExecuting || !query.trim()}
              >
                Save as Template
              </button>
            </div>
            
            {error && <div className="error-message">{error}</div>}
            
            <div className="kql-results">
              {isExecuting ? (
                <div className="loading-container">
                  <LoadingSpinner />
                  <p>Executing query...</p>
                </div>
              ) : (
                queryResults && formatResults(queryResults)
              )}
            </div>
          </div>
        </div>
        <footer>&copy; 2025 ClarityXDR. All rights reserved.</footer>
      </div>
    </>
  );
};

export default KQLPage;
