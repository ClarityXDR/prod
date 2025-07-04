import React, { useState, useEffect } from 'react';
import { Container, Row, Col, Card, Table, Button, Form, Alert, Spinner } from 'react-bootstrap';
import axios from 'axios';

const LogicAppDeployment = () => {
  const [clients, setClients] = useState([]);
  const [templates, setTemplates] = useState([]);
  const [selectedClient, setSelectedClient] = useState('');
  const [selectedTemplate, setSelectedTemplate] = useState('');
  const [logicAppName, setLogicAppName] = useState('');
  const [subscriptionId, setSubscriptionId] = useState('');
  const [resourceGroup, setResourceGroup] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(null);
  const [deployments, setDeployments] = useState([]);

  useEffect(() => {
    fetchClients();
    fetchTemplates();
    fetchDeployments();
  }, []);

  const fetchClients = async () => {
    try {
      const response = await axios.get('/api/logicapps/clients');
      setClients(response.data);
    } catch (err) {
      setError('Failed to load clients');
    }
  };

  const fetchTemplates = async () => {
    try {
      const response = await axios.get('/api/logicapps/templates');
      setTemplates(response.data);
    } catch (err) {
      setError('Failed to load templates');
    }
  };

  const fetchDeployments = async () => {
    try {
      const response = await axios.get('/api/logicapps/deployments');
      setDeployments(response.data);
    } catch (err) {
      setError('Failed to load deployment history');
    }
  };

  const handleDeployLogicApp = async () => {
    if (!selectedClient || !selectedTemplate || !logicAppName || !subscriptionId || !resourceGroup) {
      setError('All fields are required');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      setSuccess(null);

      const response = await axios.post('/api/logicapps/deploy', {
        clientId: selectedClient,
        templateName: selectedTemplate,
        logicAppName: logicAppName,
        subscriptionId: subscriptionId,
        resourceGroup: resourceGroup
      });

      setSuccess('Logic App deployed successfully');
      fetchDeployments();
      
      // Reset form
      setLogicAppName('');
    } catch (err) {
      setError(err.response?.data?.message || 'Failed to deploy Logic App');
    } finally {
      setLoading(false);
    }
  };

  const handleDisableLogicApp = async (deploymentId, clientId, subscriptionId, resourceGroup, logicAppName) => {
    try {
      setLoading(true);
      await axios.post('/api/logicapps/disable', {
        clientId,
        subscriptionId,
        resourceGroup,
        logicAppName
      });
      
      setSuccess(`Logic App ${logicAppName} disabled successfully`);
      fetchDeployments();
    } catch (err) {
      setError('Failed to disable Logic App');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Container fluid>
      <h2 className="mt-4 mb-4">Logic App Deployment</h2>
      
      {error && <Alert variant="danger">{error}</Alert>}
      {success && <Alert variant="success">{success}</Alert>}
      
      <Row>
        <Col md={6}>
          <Card className="mb-4">
            <Card.Header>Deploy Logic App</Card.Header>
            <Card.Body>
              <Form>
                <Form.Group className="mb-3">
                  <Form.Label>Client</Form.Label>
                  <Form.Select 
                    value={selectedClient}
                    onChange={(e) => setSelectedClient(e.target.value)}
                  >
                    <option value="">Select Client</option>
                    {clients.map(client => (
                      <option key={client.clientId} value={client.clientId}>{client.name}</option>
                    ))}
                  </Form.Select>
                </Form.Group>
                
                <Form.Group className="mb-3">
                  <Form.Label>Template</Form.Label>
                  <Form.Select
                    value={selectedTemplate}
                    onChange={(e) => setSelectedTemplate(e.target.value)}
                  >
                    <option value="">Select Template</option>
                    {templates.map(template => (
                      <option key={template.fileName} value={template.name}>{template.name}</option>
                    ))}
                  </Form.Select>
                </Form.Group>
                
                <Form.Group className="mb-3">
                  <Form.Label>Logic App Name</Form.Label>
                  <Form.Control
                    type="text"
                    value={logicAppName}
                    onChange={(e) => setLogicAppName(e.target.value)}
                    placeholder="Enter logic app name"
                  />
                </Form.Group>
                
                <Form.Group className="mb-3">
                  <Form.Label>Subscription ID</Form.Label>
                  <Form.Control
                    type="text"
                    value={subscriptionId}
                    onChange={(e) => setSubscriptionId(e.target.value)}
                    placeholder="Enter subscription ID"
                  />
                </Form.Group>
                
                <Form.Group className="mb-3">
                  <Form.Label>Resource Group</Form.Label>
                  <Form.Control
                    type="text"
                    value={resourceGroup}
                    onChange={(e) => setResourceGroup(e.target.value)}
                    placeholder="Enter resource group name"
                  />
                </Form.Group>
                
                <Button 
                  variant="primary" 
                  onClick={handleDeployLogicApp}
                  disabled={loading}
                >
                  {loading ? <Spinner animation="border" size="sm" /> : 'Deploy Logic App'}
                </Button>
              </Form>
            </Card.Body>
          </Card>
        </Col>
        
        <Col md={6}>
          <Card>
            <Card.Header>Deployment History</Card.Header>
            <Card.Body>
              {deployments.length === 0 ? (
                <p>No deployments found</p>
              ) : (
                <div style={{ maxHeight: '400px', overflowY: 'auto' }}>
                  <Table striped bordered hover>
                    <thead>
                      <tr>
                        <th>Client</th>
                        <th>Logic App</th>
                        <th>Template</th>
                        <th>Status</th>
                        <th>Actions</th>
                      </tr>
                    </thead>
                    <tbody>
                      {deployments.map(deployment => (
                        <tr key={deployment.id}>
                          <td>{deployment.clientName}</td>
                          <td>{deployment.logicAppName}</td>
                          <td>{deployment.templateName}</td>
                          <td>
                            <span className={`badge ${deployment.status === 'Success' ? 'bg-success' : deployment.status === 'Disabled' ? 'bg-warning' : 'bg-danger'}`}>
                              {deployment.status}
                            </span>
                          </td>
                          <td>
                            {deployment.status !== 'Disabled' && (
                              <Button
                                variant="warning"
                                size="sm"
                                onClick={() => handleDisableLogicApp(
                                  deployment.id,
                                  deployment.clientId,
                                  deployment.subscriptionId,
                                  deployment.resourceGroup,
                                  deployment.logicAppName
                                )}
                                disabled={loading}
                              >
                                Disable
                              </Button>
                            )}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </Table>
                </div>
              )}
            </Card.Body>
          </Card>
        </Col>
      </Row>
    </Container>
  );
};

export default LogicAppDeployment;
