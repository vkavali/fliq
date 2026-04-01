import { Injectable, Logger } from '@nestjs/common';
import { EventEmitter } from 'events';

@Injectable()
export class EventBusService extends EventEmitter {
  private readonly logger = new Logger(EventBusService.name);

  constructor() {
    super();
    this.setMaxListeners(50);
  }

  emit(event: string, payload: Record<string, unknown>): boolean {
    this.logger.debug(`Event: ${event} ${JSON.stringify(payload)}`);
    return super.emit(event, payload);
  }

  onEvent(event: string, handler: (payload: Record<string, unknown>) => void | Promise<void>): void {
    this.on(event, handler);
  }
}
