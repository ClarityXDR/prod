import * as React from 'react';
import * as ReactDom from 'react-dom';
import { BaseClientSideWebPart } from '@microsoft/sp-webpart-base';
import { MITRENavigator } from './components/MITRENavigator';
import { sp } from "@pnp/sp/presets/all";

export interface IMITRENavigatorWebPartProps {
  coverageListName: string;
  autoRefresh: boolean;
}

export default class MITRENavigatorWebPart extends BaseClientSideWebPart<IMITRENavigatorWebPartProps> {
  
  protected async onInit(): Promise<void> {
    await super.onInit();
    
    // Initialize PnP JS
    sp.setup({
      spfxContext: this.context
    });
  }

  public render(): void {
    const element: React.ReactElement = React.createElement(
      MITRENavigator,
      {
        coverageListName: this.properties.coverageListName || 'MITRE Coverage',
        autoRefresh: this.properties.autoRefresh,
        context: this.context
      }
    );

    ReactDom.render(element, this.domElement);
  }
}