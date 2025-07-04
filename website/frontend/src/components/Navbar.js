import React from 'react';
import { Link } from 'react-router-dom';
import './Navbar.css';

const Navbar = () => {
  return (
    <nav className="navbar">
      <div className="logo">
        <img src="https://raw.githubusercontent.com/DataGuys/ClarityXDR/main/brand-assets/Logo_Square_Dark.png" alt="ClarityXDR Logo" />
      </div>
      <div className="menu">
        <Link to="/">Home</Link>
        <Link to="/features">Features</Link>
        <Link to="/contact">Contact</Link>
      </div>
    </nav>
  );
};

export default Navbar;
