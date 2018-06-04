/*
 * Copyright (c) 2018 m2049r
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package com.m2049r.aeonwallet.util;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.HashMap;
import java.util.Map;
import java.util.TimeZone;
import java.util.concurrent.TimeUnit;

public class RestoreHeight {
    static private RestoreHeight Singleton = null;

    static public RestoreHeight getInstance() {
        if (Singleton == null) {
            synchronized (RestoreHeight.class) {
                if (Singleton == null) {
                    Singleton = new RestoreHeight();
                }
            }
        }
        return Singleton;
    }

    private Map<String, Long> blockheight = new HashMap<>();

    RestoreHeight() {
        blockheight.put("2014-07-01", 33199L);
        blockheight.put("2014-08-01", 76438L);
        blockheight.put("2014-09-01", 119160L);
        blockheight.put("2014-10-01", 159775L);
        blockheight.put("2014-11-01", 202939L);
        blockheight.put("2014-12-01", 245080L);
        blockheight.put("2015-01-01", 287638L);
        blockheight.put("2015-02-01", 330551L);
        blockheight.put("2015-03-01", 368463L);
        blockheight.put("2015-04-01", 412335L);
        blockheight.put("2015-05-01", 454056L);
        blockheight.put("2015-06-01", 498582L);
        blockheight.put("2015-07-01", 541584L);
        blockheight.put("2015-08-01", 586745L);
        blockheight.put("2015-09-01", 601813L);
        blockheight.put("2015-10-01", 612518L);
        blockheight.put("2015-11-01", 623877L);
        blockheight.put("2015-12-01", 634764L);
        blockheight.put("2016-01-01", 645860L);
        blockheight.put("2016-02-01", 656788L);
        blockheight.put("2016-03-01", 666979L);
        blockheight.put("2016-04-01", 678157L);
        blockheight.put("2016-05-01", 688749L);
        blockheight.put("2016-06-01", 699775L);
        blockheight.put("2016-07-01", 710467L);
        blockheight.put("2016-08-01", 721825L);
        blockheight.put("2016-09-01", 733175L);
        blockheight.put("2016-10-01", 743838L);
        blockheight.put("2016-11-01", 755118L);
        blockheight.put("2016-12-01", 765378L);
        blockheight.put("2017-01-01", 776857L);
        blockheight.put("2017-02-01", 787829L);
        blockheight.put("2017-03-01", 797953L);
        blockheight.put("2017-04-01", 808374L);
        blockheight.put("2017-05-01", 819274L);
        blockheight.put("2017-06-01", 830700L);
        blockheight.put("2017-07-01", 841624L);
        blockheight.put("2017-08-01", 852228L);
        blockheight.put("2017-09-01", 863601L);
        blockheight.put("2017-10-01", 874583L);
        blockheight.put("2017-11-01", 885830L);
        blockheight.put("2017-12-01", 896685L);
        blockheight.put("2018-01-01", 907962L);
        blockheight.put("2018-02-01", 919119L);
        blockheight.put("2018-03-01", 929093L);
        blockheight.put("2018-04-01", 940228L);
        blockheight.put("2018-05-01", 951203L);
        blockheight.put("2018-06-01", 962592L);
    }

    public long getHeight(String date) {
        SimpleDateFormat parser = new SimpleDateFormat("yyyy-MM-dd");
        parser.setTimeZone(TimeZone.getTimeZone("UTC"));
        parser.setLenient(false);
        try {
            Calendar cal = Calendar.getInstance(TimeZone.getTimeZone("UTC"));
            cal.set(Calendar.DST_OFFSET, 0);
            cal.setTime(parser.parse(date));
            cal.add(Calendar.DAY_OF_MONTH, -4); // give it some leeway
            if (cal.get(Calendar.YEAR) < 2014)
                return 1;
            if ((cal.get(Calendar.YEAR) == 2014) && (cal.get(Calendar.MONTH) <= 3))
                // before May 2014
                return 1;

            Calendar query = (Calendar) cal.clone();

            SimpleDateFormat formatter = new SimpleDateFormat("yyyy-MM-dd");
            formatter.setTimeZone(TimeZone.getTimeZone("UTC"));
            cal.set(Calendar.DAY_OF_MONTH, 1);
            long prevTime = cal.getTimeInMillis();
            String prevDate = formatter.format(prevTime);
            // lookup blockheight at first of the month
            Long prevBc = blockheight.get(prevDate);
            if (prevBc == null) {
                // if too recent, go back in time and find latest one we have
                while (prevBc == null) {
                    cal.add(Calendar.MONTH, -1);
                    if (cal.get(Calendar.YEAR) < 2014) {
                        throw new IllegalStateException("endless loop looking for blockheight");
                    }
                    prevTime = cal.getTimeInMillis();
                    prevDate = formatter.format(prevTime);
                    prevBc = blockheight.get(prevDate);
                }
            }
            long height = prevBc;
            // now we have a blockheight & a date ON or BEFORE the restore date requested
            if (date.equals(prevDate)) return height;
            // see if we have a blockheight after this date
            cal.add(Calendar.MONTH, 1);
            long nextTime = cal.getTimeInMillis();
            String nextDate = formatter.format(nextTime);
            Long nextBc = blockheight.get(nextDate);
            if (nextBc != null) { // we have a range - interpolate the blockheight we are looking for
                long diff = nextBc - prevBc;
                long diffDays = TimeUnit.DAYS.convert(nextTime - prevTime, TimeUnit.MILLISECONDS);
                long days = TimeUnit.DAYS.convert(query.getTimeInMillis() - prevTime,
                        TimeUnit.MILLISECONDS);
                height = Math.round(prevBc + diff * (1.0 * days / diffDays));
            } else {
                long days = TimeUnit.DAYS.convert(query.getTimeInMillis() - prevTime,
                        TimeUnit.MILLISECONDS);
                height = Math.round(prevBc + 1.0 * days * (24 * 60 / 2));
            }
            return height;
        } catch (ParseException ex) {
            throw new IllegalArgumentException(ex);
        }
    }
}
