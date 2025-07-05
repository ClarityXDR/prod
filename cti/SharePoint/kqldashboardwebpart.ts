import * as React from 'react';
import * as ReactDom from 'react-dom';
import { Version } from '@microsoft/sp-core-library';
import {
  IPropertyPaneConfiguration,
  PropertyPaneTextField
} from '@microsoft/sp-property-pane';
import { BaseClientSideWebPart } from '@microsoft/sp-webpart-base';
import { AadHttpClient, HttpClientResponse } from '@microsoft/sp-http';
import { IKQLDashboardProps } from './components/IKQLDashboardProps';
import { KQLDashboard } from './components/KQLDashboard';

export interface IKQLDashboardWebPartProps {
  defenderWorkspaceId: string;
  sentinelWorkspaceId: string;
  refreshInterval: number;
}

export default class KQLDashboardWebPart extends BaseClientSideWebPart<IKQLDashboardWebPartProps> {
  private defenderClient: AadHttpClient;
  private sentinelClient: AadHttpClient;

  protected async onInit(): Promise<void> {
    // Initialize AAD clients for API access
    this.defenderClient = await this.context.aadHttpClientFactory
      .getClient('https://api.security.microsoft.com');
    
    this.sentinelClient = await this.context.aadHttpClientFactory
      .getClient('https://api.loganalytics.io');
    
    return super.onInit();
  }

  public render(): void {
    const element: React.ReactElement<IKQLDashboardProps> = React.createElement(
      KQLDashboard,
      {
        defenderClient: this.defenderClient,
        sentinelClient: this.sentinelClient,
        defenderWorkspaceId: this.properties.defenderWorkspaceId,
        sentinelWorkspaceId: this.properties.sentinelWorkspaceId,
        refreshInterval: this.properties.refreshInterval || 300000, // 5 minutes default
        context: this.context
      }
    );

    ReactDom.render(element, this.domElement);
  }

  protected get dataVersion(): Version {
    return Version.parse('1.0');
  }

  protected getPropertyPaneConfiguration(): IPropertyPaneConfiguration {
    return {
      pages: [
        {
          header: {
            description: 'Configure KQL Dashboard Settings'
          },
          groups: [
            {
              groupName: 'Data Sources',
              groupFields: [
                PropertyPaneTextField('defenderWorkspaceId', {
                  label: 'Defender Workspace ID'
                }),
                PropertyPaneTextField('sentinelWorkspaceId', {
                  label: 'Sentinel Workspace ID'
                }),
                PropertyPaneTextField('refreshInterval', {
                  label: 'Refresh Interval (ms)'
                })
              ]
            }
          ]
        }
      ]
    };
  }
}