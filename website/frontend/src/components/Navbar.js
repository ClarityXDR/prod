import React, { useState } from 'react';
import { Link, useLocation } from 'react-router-dom';
import './Navbar.css';

const Navbar = () => {
  const [expanded, setExpanded] = useState(false);
  const location = useLocation();

  const isActive = (path) => {
    return location.pathname === path ? 'active' : '';
  };

  return (
    <nav className="navbar">
      <div className="logo">
        <Link to="/">
          <img src="https://raw.githubusercontent.com/DataGuys/ClarityXDR/main/brand-assets/Logo_Square_Dark.png" alt="ClarityXDR Logo" />
        </Link>
      </div>
      
      <div className="menu-toggle" onClick={() => setExpanded(!expanded)}>
        <i className={`fas ${expanded ? 'fa-times' : 'fa-bars'}`}></i>
      </div>
      
      <div className={`menu ${expanded ? 'expanded' : ''}`}>
        <Link to="/" className={isActive('/')}>Home</Link>
        <Link to="/dashboard" className={isActive('/dashboard')}>Dashboard</Link>
        <Link to="/agents" className={isActive('/agents')}>AI Agents</Link>
        <Link to="/kql" className={isActive('/kql')}>KQL Interface</Link>
        <Link to="/github-issues" className={isActive('/github-issues')}>GitHub Issues</Link>
        <Link to="/clients" className={isActive('/clients')}>Clients</Link>
        <Link to="/rules" className={isActive('/rules')}>MDE Rules</Link>
        <Link to="/features" className={isActive('/features')}>Features</Link>
        <Link to="/contact" className={isActive('/contact')}>Contact</Link>
        <div className="dropdown">
          <button className="dropbtn">Admin</button>
          <div className="dropdown-content">
            <Link to="/dashboard" className={isActive('/dashboard')}>Dashboard</Link>
            <Link to="/deployments" className={isActive('/deployments')}>Deployments</Link>
            <Link to="/agents" className={isActive('/agents')}>AI Agents</Link>
            <Link to="/clients" className={isActive('/clients')}>Clients</Link>
            <div className="divider"></div>
            <Link to="/github-issues" className={isActive('/github-issues')}>GitHub Issues</Link>
          </div>
        </div>
      </div>
    </nav>
  );
};

export default Navbar;
