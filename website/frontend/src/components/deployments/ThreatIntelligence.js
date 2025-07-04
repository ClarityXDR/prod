import React, { useState, useEffect } from 'react';
import { Container, Row, Col, Card, Table, Button, Form, Alert, Badge, Tabs, Tab, ProgressBar } from 'react-bootstrap';
import axios from 'axios';

const ThreatIntelligence = ({ setGlobalAlert }) => {
  const [indicators, setIndicators] = useState([]);
  const [feeds, setFeeds] = useState([]);
  const [selectedClient, setSelectedClient] = useState('');
  const [clients, setClients] = useState([]);
  const [loading, setLoading] = useState(false);
  const [stats, setStats] = useState({
    totalIndicators: 0,
    activeFeeds: 0,
    lastUpdate: null,
    syncStatus: 'idle'
  });
  const [newIndicator, setNewIndicator] = useState({
    type: 'ip',
    value: '',
    threatType: 'malware',
    confidence: 80,
    source: 'manual',
    description: ''
  });

  useEffect(() => {
    fetchClients();
    fetchIndicators();
    fetchFeeds();
    fetchStats();
  }, []);

  const fetchClients = async () => {
    try {
      const response = await axios.get('/api/threat-intel/clients');
      setClients(response.data);
    } catch (err) {
      console.error('Failed to fetch clients:', err);
    }
  };

  const fetchIndicators = async () => {
    try {
      const response = await axios.get('/api/threat-intel/indicators');
      setIndicators(response.data);
    } catch (err) {
      console.error('Failed to fetch indicators:', err);
    }
  };

  const fetchFeeds = async () => {
    try {
      const response = await axios.get('/api/threat-intel/feeds');
      setFeeds(response.data);
    } catch (err) {
      console.error('Failed to fetch feeds:', err);
    }
  };

  const fetchStats = async () => {
    try {
      const response = await axios.get('/api/threat-intel/stats');
      setStats(response.data);
    } catch (err) {
      console.error('Failed to fetch stats:', err);
    }
  };

  const handleAddIndicator = async () => {
    try {
      setLoading(true);
      await axios.post('/api/threat-intel/indicators', {
        ...newIndicator,
        clientId: selectedClient
      });
      
      setGlobalAlert({ type: 'success', message: 'Threat indicator added successfully' });
      fetchIndicators();
      setNewIndicator({
        type: 'ip',
        value: '',
        threatType: 'malware',
        confidence: 80,
        source: 'manual',
        description: ''
      });
    } catch (err) {
      setGlobalAlert({ type: 'danger', message: 'Failed to add indicator' });
    } finally {
      setLoading(false);
    }
  };

  const handleSyncToSentinel = async () => {
    if (!selectedClient) {
      setGlobalAlert({ type: 'warning', message: 'Please select a client first' });
      return;
    }

    try {
      setLoading(true);
      await axios.post('/api/threat-intel/sync-sentinel', {
        clientId: selectedClient
      });
      
      setGlobalAlert({ type: 'success', message: 'Threat indicators synced to Sentinel successfully' });
      fetchStats();
    } catch (err) {
      setGlobalAlert({ type: 'danger', message: 'Failed to sync to Sentinel' });
    } finally {
      setLoading(false);
    }
  };

  const getConfidenceBadge = (confidence) => {
    if (confidence >= 80) return <Badge bg="success">{confidence}%</Badge>;
    if (confidence >= 60) return <Badge bg="warning">{confidence}%</Badge>;
    return <Badge bg="danger">{confidence}%</Badge>;
  };

  const getIndicatorTypeBadge = (type) => {
    const typeMap = {
      'ip': 'primary',
      'domain': 'info',
      'url': 'warning',
      'hash': 'secondary',
      'email': 'dark'
    };
    return <Badge bg={typeMap[type] || 'secondary'}>{type.toUpperCase()}</Badge>;
  };

  return (
    <div className="deployment-module">
      <div className="module-header">
        <h2 className="module-title">Central Threat Intelligence</h2>
        <div className="module-actions">
          <Button variant="success" onClick={handleSyncToSentinel} disabled={loading}>
            <i className="bi bi-cloud-upload"></i> Sync to Sentinel
          </Button>
          <Button variant="outline-primary" onClick={() => { fetchIndicators(); fetchFeeds(); }}>
            <i className="bi bi-arrow-clockwise"></i> Refresh
          </Button>
        </div>
      </div>

      <Row className="mb-4">
        <Col md={3}>
          <Card>
            <Card.Body>
              <h6>Total Indicators</h6>
              <h3>{stats.totalIndicators}</h3>
            </Card.Body>
          </Card>
        </Col>
        <Col md={3}>
          <Card>
            <Card.Body>
              <h6>Active Feeds</h6>
              <h3>{stats.activeFeeds}</h3>
            </Card.Body>
          </Card>
        </Col>
        <Col md={3}>
          <Card>
            <Card.Body>
              <h6>Last Sync</h6>
              <p>{stats.lastUpdate ? new Date(stats.lastUpdate).toLocaleString() : 'Never'}</p>
            </Card.Body>
          </Card>
        </Col>
        <Col md={3}>
          <Card>
            <Card.Body>
              <h6>Sync Status</h6>
              <Badge bg={stats.syncStatus === 'syncing' ? 'warning' : 'success'}>
                {stats.syncStatus}
              </Badge>
            </Card.Body>
          </Card>
        </Col>
      </Row>

      <Row className="mb-4">
        <Col md={4}>
          <Form.Group>
            <Form.Label>Select Client</Form.Label>
            <Form.Select 
              value={selectedClient}
              onChange={(e) => setSelectedClient(e.target.value)}
            >
              <option value="">Global Indicators</option>
              {clients.map(client => (
                <option key={client.clientId} value={client.clientId}>
                  {client.name}
                </option>
              ))}
            </Form.Select>
          </Form.Group>
        </Col>
      </Row>

      <Tabs defaultActiveKey="indicators" className="mb-3">
        <Tab eventKey="indicators" title="Threat Indicators">
          <Card className="mb-3">
            <Card.Body>
              <h5>Add New Indicator</h5>
              <Form>
                <Row>
                  <Col md={2}>
                    <Form.Group>
                      <Form.Label>Type</Form.Label>
                      <Form.Select
                        value={newIndicator.type}
                        onChange={(e) => setNewIndicator({...newIndicator, type: e.target.value})}
                      >
                        <option value="ip">IP Address</option>
                        <option value="domain">Domain</option>
                        <option value="url">URL</option>
                        <option value="hash">File Hash</option>
                        <option value="email">Email</option>
                      </Form.Select>
                    </Form.Group>
                  </Col>
                  <Col md={4}>
                    <Form.Group>
                      <Form.Label>Value</Form.Label>
                      <Form.Control
                        type="text"
                        value={newIndicator.value}
                        onChange={(e) => setNewIndicator({...newIndicator, value: e.target.value})}
                        placeholder={
                          newIndicator.type === 'ip' ? '192.168.1.1' :
                          newIndicator.type === 'domain' ? 'malicious.com' :
                          newIndicator.type === 'hash' ? 'SHA256 hash' : 
                          'Enter value'
                        }
                      />
                    </Form.Group>
                  </Col>
                  <Col md={2}>
                    <Form.Group>
                      <Form.Label>Threat Type</Form.Label>
                      <Form.Select
                        value={newIndicator.threatType}
                        onChange={(e) => setNewIndicator({...newIndicator, threatType: e.target.value})}
                      >
                        <option value="malware">Malware</option>
                        <option value="phishing">Phishing</option>
                        <option value="c2">C2 Server</option>
                        <option value="botnet">Botnet</option>
                        <option value="suspicious">Suspicious</option>
                      </Form.Select>
                    </Form.Group>
                  </Col>
                  <Col md={2}>
                    <Form.Group>
                      <Form.Label>Confidence</Form.Label>
                      <Form.Control
                        type="number"
                        min="0"
                        max="100"
                        value={newIndicator.confidence}
                        onChange={(e) => setNewIndicator({...newIndicator, confidence: parseInt(e.target.value)})}
                      />
                    </Form.Group>
                  </Col>
                  <Col md={2} className="d-flex align-items-end">
                    <Button variant="primary" onClick={handleAddIndicator} disabled={loading}>
                      Add Indicator
                    </Button>
                  </Col>
                </Row>
              </Form>
            </Card.Body>
          </Card>

          <Table striped bordered hover>
            <thead>
              <tr>
                <th>Type</th>
                <th>Value</th>
                <th>Threat Type</th>
                <th>Confidence</th>
                <th>Source</th>
                <th>Added</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {indicators
                .filter(ind => !selectedClient || ind.clientId === selectedClient)
                .map(indicator => (
                  <tr key={indicator.id}>
                    <td>{getIndicatorTypeBadge(indicator.type)}</td>
                    <td className="font-monospace">{indicator.value}</td>
                    <td>{indicator.threatType}</td>
                    <td>{getConfidenceBadge(indicator.confidence)}</td>
                    <td>{indicator.source}</td>
                    <td>{new Date(indicator.createdAt).toLocaleDateString()}</td>
                    <td>
                      <Button variant="danger" size="sm">Remove</Button>
                    </td>
                  </tr>
              ))}
            </tbody>
          </Table>
        </Tab>
        
        <Tab eventKey="feeds" title="Threat Feeds">
          <Row>
            {feeds.map(feed => (
              <Col md={6} key={feed.id} className="mb-3">
                <Card>
                  <Card.Body>
                    <div className="d-flex justify-content-between align-items-start">
                      <div>
                        <h5>{feed.name}</h5>
                        <p className="text-muted">{feed.description}</p>
                        <small>
                          Last updated: {new Date(feed.lastUpdate).toLocaleString()}
                        </small>
                      </div>
                      <Form.Check 
                        type="switch"
                        checked={feed.enabled}
                        onChange={() => {/* Toggle feed */}}
                      />
                    </div>
                    <div className="mt-3">
                      <div className="d-flex justify-content-between mb-1">
                        <small>Indicators: {feed.indicatorCount}</small>
                        <small>{feed.syncProgress}%</small>
                      </div>
                      <ProgressBar now={feed.syncProgress} />
                    </div>
                  </Card.Body>
                </Card>
              </Col>
            ))}
          </Row>
        </Tab>
      </Tabs>
    </div>
  );
};

export default ThreatIntelligence;
