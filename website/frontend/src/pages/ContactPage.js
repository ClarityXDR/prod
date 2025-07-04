import React, { useState } from 'react';
import ParticlesBackground from '../components/ParticlesBackground';
import axios from 'axios';
import './PageStyles.css';

const ContactPage = () => {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    company: '',
    message: '',
  });
  const [status, setStatus] = useState({ type: '', message: '' });

  const handleChange = (e) => {
    setFormData({ ...formData, [e.target.name]: e.target.value });
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    setStatus({ type: 'info', message: 'Sending message...' });
    
    axios.post('/api/contact', formData)
      .then(response => {
        setStatus({ type: 'success', message: 'Message sent successfully! Our team will get back to you soon.' });
        setFormData({ name: '', email: '', company: '', message: '' });
      })
      .catch(error => {
        setStatus({ type: 'error', message: 'Failed to send message. Please try again later.' });
      });
  };

  return (
    <>
      <div id="particles-js">
        <ParticlesBackground isAnimated={false} />
      </div>
      <div className="main">
        <div className="content-wrapper">
          <h1>Contact Us</h1>
          
          <div className="contact-container">
            <div className="contact-info">
              <h2>Get in Touch</h2>
              <p>Have questions about ClarityXDR? Our AI customer service team is ready to assist you 24/7.</p>
              
              <div className="contact-methods">
                <div className="contact-method">
                  <h3>Email</h3>
                  <p>support@clarityxdr.com</p>
                </div>
                <div className="contact-method">
                  <h3>Phone</h3>
                  <p>+1 (800) 555-1234</p>
                </div>
                <div className="contact-method">
                  <h3>Location</h3>
                  <p>123 Tech Park Dr.<br/>Silicon Valley, CA 94123</p>
                </div>
              </div>
            </div>
            
            <div className="contact-form">
              <h2>Send Us a Message</h2>
              {status.message && (
                <div className={`alert alert-${status.type}`}>
                  {status.message}
                </div>
              )}
              <form onSubmit={handleSubmit}>
                <div className="form-group">
                  <label htmlFor="name">Name</label>
                  <input 
                    type="text" 
                    id="name" 
                    name="name" 
                    value={formData.name} 
                    onChange={handleChange} 
                    required 
                  />
                </div>
                
                <div className="form-group">
                  <label htmlFor="email">Email</label>
                  <input 
                    type="email" 
                    id="email" 
                    name="email" 
                    value={formData.email} 
                    onChange={handleChange} 
                    required 
                  />
                </div>
                
                <div className="form-group">
                  <label htmlFor="company">Company</label>
                  <input 
                    type="text" 
                    id="company" 
                    name="company" 
                    value={formData.company} 
                    onChange={handleChange} 
                  />
                </div>
                
                <div className="form-group">
                  <label htmlFor="message">Message</label>
                  <textarea 
                    id="message" 
                    name="message" 
                    value={formData.message} 
                    onChange={handleChange} 
                    required
                  ></textarea>
                </div>
                
                <button type="submit" className="btn btn-primary">Send Message</button>
              </form>
            </div>
          </div>
        </div>
        <footer>&copy; 2025 ClarityXDR. All rights reserved.</footer>
      </div>
    </>
  );
};

export default ContactPage;
