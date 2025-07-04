import React, { useState, useEffect } from 'react';
import { Container, Row, Col, Card, Table, Button, Form, Alert, Spinner, Modal, Badge } from 'react-bootstrap';
import axios from 'axios';

const LogicAppDeployment = ({ setGlobalAlert }) => {
  const [clients, setClients] = useState([]);
  const [templates, setTemplates] = useState([]);
  const [selectedClient, setSelectedClient] = useState('');
  const [selectedTemplate, setSelectedTemplate] = useState('');
  const [logicAppName, setLogicAppName] = useState('');
  const [subscriptionId, setSubscriptionId] = useState('');
  const [resourceGroup, setResourceGroup] = useState('');
  const [loading, setLoading] = useState(false);
  const [deployments, setDeployments] = useState([]);
  const [showAdvancedSettings, setShowAdvancedSettings] = useState(false);
  const [azureCredentials, setAzureCredentials] = useState({
    tenantId: '',
    clientId: '',
    clientSecret: ''
  });
  const [stats, setStats] = useState({
    total: 0,
    active: 0,
    failed: 0,
    pending: 0
  });

  useEffect(() => {
    fetchInitialData();
  }, []);

  const fetchInitialData = async () => {
    await Promise.all([
      fetchClients(),
      fetchTemplates(),
      fetchDeployments()
    ]);
  };

  const fetchClients = async () => {
    try {
      const response = await axios.get('/api/logicapps/clients');
      setClients(response.data);
    } catch (err) {
      setGlobalAlert({ type: 'danger', message: 'Failed to load clients' });
    }
  };

  const fetchTemplates = async () => {
    try {
      const response = await axios.get('/api/logicapps/templates');
      setTemplates(response.data);
    } catch (err) {
      setGlobalAlert({ type: 'danger', message: 'Failed to load templates' });
    }
  };

  const fetchDeployments = async () => {
    try {
      const response = await axios.get('/api/logicapps/deployments');
      setDeployments(response.data.deployments || []);
      setStats(response.data.stats || { total: 0, active: 0, failed: 0, pending: 0 });
    } catch (err) {
      console.error('Failed to load deployments:', err);
    }
  };

  const handleDeployLogicApp = async () => {
    if (!selectedClient || !selectedTemplate || !logicAppName || !subscriptionId || !resourceGroup) {
      setGlobalAlert({ type: 'warning', message: 'All fields are required' });
      return;
    }

    try {
      setLoading(true);
      const deploymentData = {
        clientId: selectedClient,
        templateName: selectedTemplate,
        logicAppName: logicAppName,
        subscriptionId: subscriptionId,
        resourceGroup: resourceGroup
      };

      // Include Azure credentials if provided
      if (showAdvancedSettings && azureCredentials.tenantId) {
        deploymentData.azureCredentials = azureCredentials;
      }

      const response = await axios.post('/api/logicapps/deploy', deploymentData);

      setGlobalAlert({ type: 'success', message: 'Logic App deployment initiated successfully' });
      fetchDeployments();
      
      // Reset form
      setLogicAppName('');
      setSelectedTemplate('');
    } catch (err) {
      setGlobalAlert({ 
        type: 'danger', 
        message: err.response?.data?.message || 'Failed to deploy Logic App' 
      });
    } finally {
      setLoading(false);
    }
  };

  const handleDisableLogicApp = async (deployment) => {
    if (!window.confirm(`Are you sure you want to disable ${deployment.logicAppName}?`)) {
      return;
    }

    try {
      setLoading(true);
      await axios.post('/api/logicapps/disable', {
        clientId: deployment.clientId,
        subscriptionId: deployment.subscriptionId,
        resourceGroup: deployment.resourceGroup,
        logicAppName: deployment.logicAppName
      });
      
      setGlobalAlert({ type: 'success', message: `Logic App ${deployment.logicAppName} disabled successfully` });
      fetchDeployments();
    } catch (err) {
      setGlobalAlert({ type: 'danger', message: 'Failed to disable Logic App' });
    } finally {
      setLoading(false);
    }
  };

  const getStatusBadge = (status) => {
    const statusMap = {
      'Success': 'success',
      'Active': 'success',
      'Failed': 'danger',
      'Pending': 'warning',
      'Disabled': 'secondary'
    };
    return <Badge bg={statusMap[status] || 'info'}>{status}</Badge>;
  };

  return (
    <div className="deployment-module">
      <div className="module-header">
        <h2 className="module-title">Logic App Deployment</h2>
        <div className="module-actions">
          <Button variant="outline-primary" onClick={fetchDeployments}>
            <i className="bi bi-arrow-clockwise"></i> Refresh
          </Button>
        </div>
      </div>

      <div className="deployment-stats mb-4">
        <div className="stat-card">
          <div className="stat-value">{stats.total}</div>
          <div className="stat-label">Total Deployments</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{stats.active}</div>
          <div className="stat-label">Active</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{stats.failed}</div>
          <div className="stat-label">Failed</div>
        </div>
        <div className="stat-card">
          <div className="stat-value">{stats.pending}</div>
          <div className="stat-label">Pending</div>
        </div>
      </div>

      <Card className="deployment-form">
        <Card.Body>
          <h4>Deploy New Logic App</h4>
          <Form>
            <Row>
              <Col md={6}>
                <Form.Group className="mb-3">
                  <Form.Label>Client</Form.Label>
                  <Form.Select 
                    value={selectedClient}
                    onChange={(e) => setSelectedClient(e.target.value)}
                    className="client-selector"
                  >
                    <option value="">Select Client</option>
                    {clients.map(client => (
                      <option key={client.clientId} value={client.clientId}>
                        {client.name} ({client.clientId})
                      </option>
                    ))}
                  </Form.Select>
                </Form.Group>
              </Col>
              
              <Col md={6}>
                <Form.Group className="mb-3">
                  <Form.Label>Logic App Name</Form.Label>
                  <Form.Control
                    type="text"
                    value={logicAppName}
                    onChange={(e) => setLogicAppName(e.target.value)}
                    placeholder="e.g., clarity-sentinel-integration"
                  />
                  <Form.Text className="text-muted">
                    Must be unique within the resource group
                  </Form.Text>
                </Form.Group>
              </Col>
            </Row>

            <Row>
              <Col md={6}>
                <Form.Group className="mb-3">
                  <Form.Label>Subscription ID</Form.Label>
                  <Form.Control
                    type="text"
                    value={subscriptionId}
                    onChange={(e) => setSubscriptionId(e.target.value)}
                    placeholder="00000000-0000-0000-0000-000000000000"
                  />
                </Form.Group>
              </Col>
              
              <Col md={6}>
                <Form.Group className="mb-3">
                  <Form.Label>Resource Group</Form.Label>
                  <Form.Control
                    type="text"
                    value={resourceGroup}
                    onChange={(e) => setResourceGroup(e.target.value)}
                    placeholder="e.g., rg-security-prod"
                  />
                </Form.Group>
              </Col>
            </Row>

            <Form.Group className="mb-3">
              <Form.Label>Template</Form.Label>
              <div className="template-selector">
                {templates.map(template => (
                  <div
                    key={template.name}
                    className={`template-card ${selectedTemplate === template.name ? 'selected' : ''}`}
                    onClick={() => setSelectedTemplate(template.name)}
                  >
                    <h6>{template.displayName || template.name}</h6>
                    <small className="text-muted">{template.description || 'Logic App template'}</small>
                  </div>
                ))}
              </div>
            </Form.Group>

            <Button 
              variant="link" 
              onClick={() => setShowAdvancedSettings(!showAdvancedSettings)}
              className="mb-3"
            >
              {showAdvancedSettings ? 'Hide' : 'Show'} Advanced Settings
            </Button>

            {showAdvancedSettings && (
              <Card className="mb-3">
                <Card.Body>
                  <h6>Azure Service Principal (Optional)</h6>
                  <Row>
                    <Col md={4}>
                      <Form.Group className="mb-3">
                        <Form.Label>Tenant ID</Form.Label>
                        <Form.Control
                          type="text"
                          value={azureCredentials.tenantId}
                          onChange={(e) => setAzureCredentials({...azureCredentials, tenantId: e.target.value})}
                        />
                      </Form.Group>
                    </Col>
                    <Col md={4}>
                      <Form.Group className="mb-3">
                        <Form.Label>Client ID</Form.Label>
                        <Form.Control
                          type="text"
                          value={azureCredentials.clientId}
                          onChange={(e) => setAzureCredentials({...azureCredentials, clientId: e.target.value})}
                        />
                      </Form.Group>
                    </Col>
                    <Col md={4}>
                      <Form.Group className="mb-3">
                        <Form.Label>Client Secret</Form.Label>
                        <Form.Control
                          type="password"
                          value={azureCredentials.clientSecret}
                          onChange={(e) => setAzureCredentials({...azureCredentials, clientSecret: e.target.value})}
                        />
                      </Form.Group>
                    </Col>
                  </Row>
                </Card.Body>
              </Card>
            )}
            
            <Button 
              variant="primary" 
              onClick={handleDeployLogicApp}
              disabled={loading}
              size="lg"
            >
              {loading ? <Spinner animation="border" size="sm" /> : 'Deploy Logic App'}
            </Button>
          </Form>
        </Card.Body>
      </Card>

      <div className="deployment-history">
        <h4 className="mb-3">Deployment History</h4>
        {deployments.length === 0 ? (
          <Alert variant="info">No deployments found</Alert>
        ) : (
          <div className="history-table">
            <Table striped bordered hover responsive>
              <thead>
                <tr>
                  <th>Client</th>
                  <th>Logic App</th>
                  <th>Template</th>
                  <th>Resource Group</th>
                  <th>Status</th>
                  <th>Deployed</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {deployments.map(deployment => (
                  <tr key={deployment.id}>
                    <td>{deployment.clientName}</td>
                    <td>{deployment.logicAppName}</td>
                    <td>{deployment.templateName}</td>
                    <td>{deployment.resourceGroup}</td>
                    <td>{getStatusBadge(deployment.status)}</td>
                    <td>{new Date(deployment.deployedAt).toLocaleDateString()}</td>
                    <td>
                      <Button
                        variant="warning"
                        size="sm"
                        onClick={() => handleDisableLogicApp(deployment)}
                        disabled={loading || deployment.status === 'Disabled'}
                      >
                        Disable
                      </Button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </Table>
          </div>
        )}
      </div>
    </div>
  );
};

export default LogicAppDeployment;
