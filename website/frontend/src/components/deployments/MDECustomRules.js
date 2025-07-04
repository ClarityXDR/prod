import React, { useState, useEffect } from 'react';
import { Container, Row, Col, Card, Table, Button, Form, Alert, Modal, Badge, Tabs, Tab } from 'react-bootstrap';
import axios from 'axios';
import CodeMirror from '@uiw/react-codemirror';
import { sql } from '@codemirror/lang-sql';

const MDECustomRules = ({ setGlobalAlert }) => {
  const [clients, setClients] = useState([]);
  const [rules, setRules] = useState([]);
  const [deployedRules, setDeployedRules] = useState([]);
  const [selectedClient, setSelectedClient] = useState('');
  const [selectedRule, setSelectedRule] = useState(null);
  const [showRuleModal, setShowRuleModal] = useState(false);
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [loading, setLoading] = useState(false);
  const [newRule, setNewRule] = useState({
    title: '',
    description: '',
    severity: 'medium',
    category: '',
    kqlQuery: '',
    enabled: true
  });

  useEffect(() => {
    fetchClients();
    fetchRules();
    fetchDeployedRules();
  }, []);

  const fetchClients = async () => {
    try {
      const response = await axios.get('/api/mde/clients');
      setClients(response.data);
    } catch (err) {
      console.error('Failed to fetch clients:', err);
    }
  };

  const fetchRules = async () => {
    try {
      const response = await axios.get('/api/mde/rules/templates');
      setRules(response.data);
    } catch (err) {
      console.error('Failed to fetch rules:', err);
    }
  };

  const fetchDeployedRules = async () => {
    try {
      const response = await axios.get('/api/mde/rules/deployed');
      setDeployedRules(response.data);
    } catch (err) {
      console.error('Failed to fetch deployed rules:', err);
    }
  };

  const handleDeployRule = async (rule) => {
    if (!selectedClient) {
      setGlobalAlert({ type: 'warning', message: 'Please select a client first' });
      return;
    }

    try {
      setLoading(true);
      await axios.post('/api/mde/rules/deploy', {
        clientId: selectedClient,
        ruleId: rule.id,
        customizations: {
          enabled: true
        }
      });
      
      setGlobalAlert({ type: 'success', message: `Rule "${rule.title}" deployed successfully` });
      fetchDeployedRules();
    } catch (err) {
      setGlobalAlert({ type: 'danger', message: 'Failed to deploy rule' });
    } finally {
      setLoading(false);
    }
  };

  const handleCreateCustomRule = async () => {
    try {
      setLoading(true);
      await axios.post('/api/mde/rules/create', {
        ...newRule,
        clientId: selectedClient
      });
      
      setGlobalAlert({ type: 'success', message: 'Custom rule created successfully' });
      setShowCreateModal(false);
      fetchRules();
      setNewRule({
        title: '',
        description: '',
        severity: 'medium',
        category: '',
        kqlQuery: '',
        enabled: true
      });
    } catch (err) {
      setGlobalAlert({ type: 'danger', message: 'Failed to create rule' });
    } finally {
      setLoading(false);
    }
  };

  const getSeverityBadge = (severity) => {
    const severityMap = {
      'low': 'info',
      'medium': 'warning',
      'high': 'danger',
      'critical': 'danger'
    };
    return <Badge bg={severityMap[severity] || 'secondary'}>{severity}</Badge>;
  };

  return (
    <div className="deployment-module">
      <div className="module-header">
        <h2 className="module-title">MDE Custom Detection Rules</h2>
        <div className="module-actions">
          <Button variant="success" onClick={() => setShowCreateModal(true)}>
            <i className="bi bi-plus-circle"></i> Create Custom Rule
          </Button>
          <Button variant="outline-primary" onClick={() => { fetchRules(); fetchDeployedRules(); }}>
            <i className="bi bi-arrow-clockwise"></i> Refresh
          </Button>
        </div>
      </div>

      <Row className="mb-4">
        <Col md={4}>
          <Form.Group>
            <Form.Label>Select Client</Form.Label>
            <Form.Select 
              value={selectedClient}
              onChange={(e) => setSelectedClient(e.target.value)}
            >
              <option value="">All Clients</option>
              {clients.map(client => (
                <option key={client.clientId} value={client.clientId}>
                  {client.name}
                </option>
              ))}
            </Form.Select>
          </Form.Group>
        </Col>
      </Row>

      <Tabs defaultActiveKey="templates" className="mb-3">
        <Tab eventKey="templates" title="Rule Templates">
          <div className="rules-grid">
            {rules.map(rule => (
              <Card key={rule.id} className="mb-3">
                <Card.Body>
                  <div className="d-flex justify-content-between align-items-start mb-2">
                    <h5>{rule.title}</h5>
                    {getSeverityBadge(rule.severity)}
                  </div>
                  <p className="text-muted">{rule.description}</p>
                  <div className="d-flex justify-content-between align-items-center">
                    <small className="text-muted">Category: {rule.category}</small>
                    <div>
                      <Button 
                        variant="outline-info" 
                        size="sm" 
                        className="me-2"
                        onClick={() => { setSelectedRule(rule); setShowRuleModal(true); }}
                      >
                        View Details
                      </Button>
                      <Button 
                        variant="primary" 
                        size="sm"
                        onClick={() => handleDeployRule(rule)}
                        disabled={loading || !selectedClient}
                      >
                        Deploy
                      </Button>
                    </div>
                  </div>
                </Card.Body>
              </Card>
            ))}
          </div>
        </Tab>
        
        <Tab eventKey="deployed" title="Deployed Rules">
          <Table striped bordered hover>
            <thead>
              <tr>
                <th>Client</th>
                <th>Rule</th>
                <th>Severity</th>
                <th>Status</th>
                <th>Deployed</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {deployedRules
                .filter(rule => !selectedClient || rule.clientId === selectedClient)
                .map(rule => (
                  <tr key={rule.id}>
                    <td>{rule.clientName}</td>
                    <td>{rule.title}</td>
                    <td>{getSeverityBadge(rule.severity)}</td>
                    <td>
                      <Badge bg={rule.enabled ? 'success' : 'secondary'}>
                        {rule.enabled ? 'Active' : 'Disabled'}
                      </Badge>
                    </td>
                    <td>{new Date(rule.deployedAt).toLocaleDateString()}</td>
                    <td>
                      <Button 
                        variant={rule.enabled ? 'warning' : 'success'} 
                        size="sm"
                        onClick={() => {/* Toggle rule status */}}
                      >
                        {rule.enabled ? 'Disable' : 'Enable'}
                      </Button>
                    </td>
                  </tr>
              ))}
            </tbody>
          </Table>
        </Tab>
      </Tabs>

      {/* Rule Details Modal */}
      <Modal show={showRuleModal} onHide={() => setShowRuleModal(false)} size="lg">
        <Modal.Header closeButton>
          <Modal.Title>{selectedRule?.title}</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          {selectedRule && (
            <>
              <p><strong>Description:</strong> {selectedRule.description}</p>
              <p><strong>Severity:</strong> {getSeverityBadge(selectedRule.severity)}</p>
              <p><strong>Category:</strong> {selectedRule.category}</p>
              <h6>KQL Query:</h6>
              <CodeMirror
                value={selectedRule.kqlQuery}
                height="200px"
                extensions={[sql()]}
                editable={false}
                theme="light"
              />
            </>
          )}
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={() => setShowRuleModal(false)}>
            Close
          </Button>
          <Button 
            variant="primary" 
            onClick={() => { handleDeployRule(selectedRule); setShowRuleModal(false); }}
            disabled={!selectedClient}
          >
            Deploy Rule
          </Button>
        </Modal.Footer>
      </Modal>

      {/* Create Custom Rule Modal */}
      <Modal show={showCreateModal} onHide={() => setShowCreateModal(false)} size="lg">
        <Modal.Header closeButton>
          <Modal.Title>Create Custom Detection Rule</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <Form>
            <Form.Group className="mb-3">
              <Form.Label>Rule Title</Form.Label>
              <Form.Control
                type="text"
                value={newRule.title}
                onChange={(e) => setNewRule({...newRule, title: e.target.value})}
                placeholder="e.g., Suspicious PowerShell Activity"
              />
            </Form.Group>

            <Form.Group className="mb-3">
              <Form.Label>Description</Form.Label>
              <Form.Control
                as="textarea"
                rows={3}
                value={newRule.description}
                onChange={(e) => setNewRule({...newRule, description: e.target.value})}
              />
            </Form.Group>

            <Row>
              <Col md={6}>
                <Form.Group className="mb-3">
                  <Form.Label>Severity</Form.Label>
                  <Form.Select
                    value={newRule.severity}
                    onChange={(e) => setNewRule({...newRule, severity: e.target.value})}
                  >
                    <option value="low">Low</option>
                    <option value="medium">Medium</option>
                    <option value="high">High</option>
                    <option value="critical">Critical</option>
                  </Form.Select>
                </Form.Group>
              </Col>
              <Col md={6}>
                <Form.Group className="mb-3">
                  <Form.Label>Category</Form.Label>
                  <Form.Control
                    type="text"
                    value={newRule.category}
                    onChange={(e) => setNewRule({...newRule, category: e.target.value})}
                    placeholder="e.g., Execution"
                  />
                </Form.Group>
              </Col>
            </Row>

            <Form.Group className="mb-3">
              <Form.Label>KQL Query</Form.Label>
              <CodeMirror
                value={newRule.kqlQuery}
                onChange={(value) => setNewRule({...newRule, kqlQuery: value})}
                height="200px"
                extensions={[sql()]}
                theme="light"
                placeholder="Enter your KQL detection query..."
              />
            </Form.Group>
          </Form>
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={() => setShowCreateModal(false)}>
            Cancel
          </Button>
          <Button variant="primary" onClick={handleCreateCustomRule} disabled={loading}>
            Create Rule
          </Button>
        </Modal.Footer>
      </Modal>
    </div>
  );
};

export default MDECustomRules;
