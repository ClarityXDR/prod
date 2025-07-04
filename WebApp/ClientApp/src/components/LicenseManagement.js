import React, { useState, useEffect } from 'react';
import { Container, Row, Col, Card, Table, Button, Form, Alert, Modal } from 'react-bootstrap';
import axios from 'axios';
import { format } from 'date-fns';

const LicenseManagement = () => {
  const [clients, setClients] = useState([]);
  const [licenses, setLicenses] = useState([]);
  const [selectedClient, setSelectedClient] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [showAddLicenseModal, setShowAddLicenseModal] = useState(false);
  const [newLicense, setNewLicense] = useState({
    expirationDate: format(new Date().setMonth(new Date().getMonth() + 12), 'yyyy-MM-dd'),
    isActive: true,
    notes: ''
  });

  useEffect(() => {
    fetchClients();
  }, []);

  const fetchClients = async () => {
    try {
      setLoading(true);
      const response = await axios.get('/api/licensing/clients');
      setClients(response.data);
      setLoading(false);
    } catch (err) {
      setError('Failed to load clients');
      setLoading(false);
    }
  };

  const fetchLicensesForClient = async (clientId) => {
    try {
      setLoading(true);
      const response = await axios.get(`/api/licensing/clients/${clientId}/licenses`);
      setLicenses(response.data);
      setLoading(false);
    } catch (err) {
      setError('Failed to load licenses');
      setLoading(false);
    }
  };

  const handleClientSelect = (clientId) => {
    setSelectedClient(clientId);
    fetchLicensesForClient(clientId);
  };

  const handleCreateLicense = async () => {
    try {
      setLoading(true);
      await axios.post(`/api/licensing/clients/${selectedClient}/licenses`, newLicense);
      fetchLicensesForClient(selectedClient);
      setShowAddLicenseModal(false);
      setNewLicense({
        expirationDate: format(new Date().setMonth(new Date().getMonth() + 12), 'yyyy-MM-dd'),
        isActive: true,
        notes: ''
      });
    } catch (err) {
      setError('Failed to create license');
    } finally {
      setLoading(false);
    }
  };

  const handleToggleLicenseStatus = async (licenseId, currentStatus) => {
    try {
      setLoading(true);
      await axios.patch(`/api/licensing/licenses/${licenseId}`, {
        isActive: !currentStatus
      });
      fetchLicensesForClient(selectedClient);
    } catch (err) {
      setError('Failed to update license');
    } finally {
      setLoading(false);
    }
  };

  return (
    <Container fluid>
      <h2 className="mt-4 mb-4">License Management</h2>
      
      {error && <Alert variant="danger">{error}</Alert>}
      
      <Row>
        <Col md={4}>
          <Card className="mb-4">
            <Card.Header>Clients</Card.Header>
            <Card.Body>
              {loading && <p>Loading clients...</p>}
              {!loading && clients.length === 0 && <p>No clients found</p>}
              <div style={{ maxHeight: '400px', overflowY: 'auto' }}>
                <Table hover>
                  <thead>
                    <tr>
                      <th>Name</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {clients.map(client => (
                      <tr key={client.id} className={selectedClient === client.id ? 'table-primary' : ''}>
                        <td>{client.name}</td>
                        <td>
                          <Button 
                            size="sm" 
                            variant={selectedClient === client.id ? "primary" : "outline-primary"}
                            onClick={() => handleClientSelect(client.id)}
                          >
                            View
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </Table>
              </div>
            </Card.Body>
          </Card>
        </Col>
        
        <Col md={8}>
          <Card>
            <Card.Header className="d-flex justify-content-between align-items-center">
              <span>Licenses</span>
              {selectedClient && (
                <Button 
                  variant="success" 
                  size="sm"
                  onClick={() => setShowAddLicenseModal(true)}
                >
                  Add License
                </Button>
              )}
            </Card.Header>
            <Card.Body>
              {!selectedClient && <p>Select a client to view licenses</p>}
              {selectedClient && loading && <p>Loading licenses...</p>}
              {selectedClient && !loading && licenses.length === 0 && <p>No licenses found for this client</p>}
              {selectedClient && !loading && licenses.length > 0 && (
                <Table striped bordered hover>
                  <thead>
                    <tr>
                      <th>License Key</th>
                      <th>Issue Date</th>
                      <th>Expiration Date</th>
                      <th>Status</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    {licenses.map(license => (
                      <tr key={license.id}>
                        <td>{license.licenseKey}</td>
                        <td>{format(new Date(license.issueDate), 'yyyy-MM-dd')}</td>
                        <td>{format(new Date(license.expirationDate), 'yyyy-MM-dd')}</td>
                        <td>
                          <span className={`badge ${license.isActive ? 'bg-success' : 'bg-danger'}`}>
                            {license.isActive ? 'Active' : 'Inactive'}
                          </span>
                        </td>
                        <td>
                          <Button 
                            variant={license.isActive ? "warning" : "success"} 
                            size="sm"
                            onClick={() => handleToggleLicenseStatus(license.id, license.isActive)}
                          >
                            {license.isActive ? 'Deactivate' : 'Activate'}
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </Table>
              )}
            </Card.Body>
          </Card>
        </Col>
      </Row>

      {/* Add License Modal */}
      <Modal show={showAddLicenseModal} onHide={() => setShowAddLicenseModal(false)}>
        <Modal.Header closeButton>
          <Modal.Title>Create New License</Modal.Title>
        </Modal.Header>
        <Modal.Body>
          <Form>
            <Form.Group className="mb-3">
              <Form.Label>Expiration Date</Form.Label>
              <Form.Control
                type="date"
                value={newLicense.expirationDate}
                onChange={(e) => setNewLicense({...newLicense, expirationDate: e.target.value})}
              />
            </Form.Group>
            <Form.Group className="mb-3">
              <Form.Check
                type="checkbox"
                label="Active"
                checked={newLicense.isActive}
                onChange={(e) => setNewLicense({...newLicense, isActive: e.target.checked})}
              />
            </Form.Group>
            <Form.Group className="mb-3">
              <Form.Label>Notes</Form.Label>
              <Form.Control
                as="textarea"
                rows={3}
                value={newLicense.notes}
                onChange={(e) => setNewLicense({...newLicense, notes: e.target.value})}
              />
            </Form.Group>
          </Form>
        </Modal.Body>
        <Modal.Footer>
          <Button variant="secondary" onClick={() => setShowAddLicenseModal(false)}>
            Cancel
          </Button>
          <Button variant="primary" onClick={handleCreateLicense}>
            Create License
          </Button>
        </Modal.Footer>
      </Modal>
    </Container>
  );
};

export default LicenseManagement;
