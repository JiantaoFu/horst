/* horst - Highly Optimized Radio Scanning Tool
 *
 * Copyright (C) 2015 Bruno Randolf <br1@einfach.org>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

#include "ifctrl.h"
#include "main.h"
#include "ieee80211_util.h"

#import <CoreWLAN/CoreWLAN.h>

bool osx_set_freq(const char *interface, unsigned int freq)
{
    int channel = ieee80211_freq2channel(freq);

    CWWiFiClient * wifiClient = [CWWiFiClient sharedWiFiClient];
    NSString * interfaceName = [[NSString alloc] initWithUTF8String: interface];
    CWInterface * currentInterface = [wifiClient interfaceWithName: interfaceName];

    NSSet * channels = [currentInterface supportedWLANChannels];
    CWChannel * wlanChannel = nil;
    for (CWChannel * _wlanChannel in channels) {
        if ([_wlanChannel channelNumber] == channel)
            wlanChannel = _wlanChannel;
    }

    bool ret = true;
    if (wlanChannel != nil) {
        NSError *err = nil;
        BOOL result = [currentInterface setWLANChannel:wlanChannel error:&err];
        if( !result ) {
            printlog("set channel %ld err: %s", (long)[wlanChannel channelNumber], [[err localizedDescription] UTF8String]);
            ret = false;
        } else {
            //printlog("set channel %ld success: %s", (long)[wlanChannel channelNumber]);
        }
    }

    [currentInterface release];
    [interfaceName release];
//    [wifiClient release];

    return ret;
}

int osx_get_channels(const char* devname, struct channel_list* channels) {
    CWWiFiClient * wifiClient = [CWWiFiClient sharedWiFiClient];
    NSString * interfaceName = [[NSString alloc] initWithUTF8String: devname];
    CWInterface * currentInterface = [wifiClient interfaceWithName: interfaceName];
    NSSet<CWChannel *> *supportedChannelsSet = [currentInterface supportedWLANChannels];
    NSSortDescriptor *sort = [NSSortDescriptor sortDescriptorWithKey:@"channelNumber" ascending:YES];
    NSArray * sortedChannels = [supportedChannelsSet sortedArrayUsingDescriptors:[NSArray arrayWithObject:sort]];

    channels->band[0].num_channels = 0;
    channels->band[1].num_channels = 0;
    channels->band[0].max_chan_width = CHAN_WIDTH_20;
    channels->band[1].max_chan_width = CHAN_WIDTH_40;
    channels->num_bands = 2;

    int i = 0;
    NSInteger lastNum = -1;
    for( id eachChannel in sortedChannels )
    {
        NSInteger num = [eachChannel channelNumber];
        CWChannelBand band = [eachChannel channelBand];
        CWChannelWidth width = [eachChannel channelWidth];
        printlog("num: %ld, band: %ld, width: %ld", num, (long)band, (long)width);

        if (lastNum != num ) {
            channel_list_add(ieee80211_channel2freq(num));
            
            int bandIdx = -1;
            if( kCWChannelBand2GHz == band ) {
                bandIdx = 0;
            } else if( kCWChannelBand5GHz == band ) {
                bandIdx = 1;
            }
            if( bandIdx >= 0) {
                ++(channels->band[bandIdx].num_channels);
//                switch (width) {
//                    case kCWChannelWidth20MHz:
//                        channels->band[bandIdx].max_chan_width = CHAN_WIDTH_20;
//                        break;
//
//                    case kCWChannelWidth40MHz:
//                        channels->band[bandIdx].max_chan_width = CHAN_WIDTH_40;
//                        break;
//
//                    case kCWChannelWidth80MHz:
//                        channels->band[bandIdx].max_chan_width = CHAN_WIDTH_80;
//                        break;
//
//                    case kCWChannelWidth160MHz:
//                        channels->band[bandIdx].max_chan_width = CHAN_WIDTH_160;
//                        break;
//
//                    default:
//                        break;
//                }

                channels->band[bandIdx].streams_rx = 0;
                channels->band[bandIdx].streams_tx = 0;
            }
        }

        lastNum = num;
        if( ++i > MAX_CHANNELS) {
            break;
        }
    }

    printlog("band 0 channels: %d", channels->band[0].num_channels);
    printlog("band 1 channels: %d", channels->band[1].num_channels);

    [supportedChannelsSet release];
    [currentInterface release];
    [interfaceName release];
//    [wifiClient release];

    return i;
}

bool ifctrl_init() {
    CWWiFiClient * wifiClient = [CWWiFiClient sharedWiFiClient];
    NSString * interfaceName = [[NSString alloc] initWithUTF8String: conf.ifname];
    CWInterface * currentInterface = [wifiClient interfaceWithName: interfaceName];
    [currentInterface disassociate];

    [currentInterface release];
    [interfaceName release];
//    [wifiClient release];

	return true;
};

void ifctrl_finish() {
};

bool ifctrl_iwadd_monitor(__attribute__((unused))const char *interface, __attribute__((unused))const char *monitor_interface) {
	printlog("add monitor: not implemented");
	return false;
};

bool ifctrl_iwdel(__attribute__((unused))const char *interface) {
	printlog("iwdel: not implemented");
	return false;
};

bool ifctrl_flags(__attribute__((unused))const char *interface, __attribute__((unused))bool up, __attribute__((unused))bool promisc) {
        printlog("ifctrl_flags: not implemeneted");
        return true;
}

bool ifctrl_iwset_monitor(__attribute__((unused))const char *interface) {
	printlog("set monitor: not implemented");
	return false;
};

bool ifctrl_iwset_freq(__attribute__((unused))const char *interface, __attribute__((unused))unsigned int freq,
                       __attribute__((unused))enum chan_width width, __attribute__((unused))unsigned int center) {
    if (osx_set_freq(interface, freq))
        return true;
    return false;
};

bool ifctrl_iwget_interface_info(__attribute__((unused))const char *interface) {
	printlog("get interface info: not implemented");
	return false;
};

bool ifctrl_iwget_freqlist(__attribute__((unused))int phy,  struct channel_list* channels) {
    int num_channels = osx_get_channels(conf.ifname, channels);
    if (num_channels)
        return true;
    return false;
};

bool ifctrl_is_monitor() {
	return true;
};
