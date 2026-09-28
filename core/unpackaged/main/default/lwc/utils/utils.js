/* Copyright (c) 2022 ForeFront, Inc. All Rights Reserved. Subject to ForeFront, Inc. licensing. */


export const hasOwn = (obj, key) => Object.prototype.hasOwnProperty.call(obj, key);

export const resolvePath = (path, object) => {
    return path.split('.').reduce((acc, v) => acc && acc[v], object)
}

export function debounce(func, timeout = 300){
    let timer;
    return (...args) => {
        clearTimeout(timer);
        timer = setTimeout(() => { func.apply(this, args); }, timeout);
    };
}

export const groupBy = (arr, key) => {
    return (arr || []).reduce((acc, item) => {
        const keyValue = resolvePath(key, item);
        (acc[keyValue] = acc[keyValue] || []).push(item);

        return acc;

    }, {})
}

export const groupBySingle = (arr, key) => {
    return (arr || []).reduce((acc, item) => {
        const keyValue = resolvePath(key, item);
        acc[keyValue] = item;
        return acc;
    }, {})
}

export const uuidv4 = () => {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
        const r = Math.random() * 16 | 0, v = c === 'x' ? r : (r & 0x3 | 0x8);
        return v.toString(16);
    });
}

export const sureThing = promise => args =>
    promise(args)
    .then(data => ({ok: true, data}))
    .catch(error => Promise.resolve({ok: false, error}));

export const deepClone = (object) => {
    return JSON.parse(JSON.stringify(object));
}

export const multiSelectToArray = multiselect => multiselect?.split(';') ?? [];

export const lower = s => (s || '').toLowerCase()

export const logProxy = (msg, data) => {
    if(data !== null || true || data === 0 || data === false)  {
        console.log(msg, JSON.parse(JSON.stringify(data)));
    } else {
        console.log(msg, 'Undefined');
    }
}

export const readFileB64 = file => new Promise((resolve, reject) => {
    const reader = new FileReader();

    reader.onload = () => {
        resolve(reader.result.split(",")[1]);
    };
    reader.onerror = error => {
        reject(error)
    };

    reader.readAsDataURL(file);
})

export const flattenJSON = data => {
    let result = {};
    function recurse (cur, prop) {
        if (Object(cur) !== cur) {
            result[prop] = cur;
        } else if (Array.isArray(cur)) {
            for(let i=0, l=cur.length; i<l; i++)
                recurse(cur[i], prop + "[" + i + "]");
            if (l === 0)
                result[prop] = [];
        } else {
            let isEmpty = true;
            for (let p in cur) {
                isEmpty = false;
                recurse(cur[p], prop ? prop+"."+p : p);
            }
            if (isEmpty && prop)
                result[prop] = {};
        }
    }
    recurse(data, "");
    return result;
}

export const poll = async ({ fn, validate, interval, maxAttempts }) => {
    let attempts = 0;

    const executePoll = async (resolve, reject) => {
        const result = await fn();
        attempts++;

        if (validate(result)) {
            return resolve(result);
        } else if (maxAttempts && attempts === maxAttempts) {
            return reject(new Error('Exceeded max attempts'));
        } else {
            setTimeout(executePoll, interval, resolve, reject);
        }
    };

    return new Promise(executePoll);
};

/**
 * Converts date to string in YYYY-MM-DD format. It can be used instead of Date's toISOString()
 * as it does not take into account users TimeZone.
 * @param {Date} date Date to be converted to string
 * @returns String representing date in YYYY-MM-DD format
 */
export const dateToIsoString = (/** @type {Date} */ date) => {
    const yearStr = "" + date.getFullYear();
    const monthStr = ("" + (date.getMonth() + 1)).padStart(2, "0");
    const dayStr = ("" + date.getDate()).padStart(2, "0");
    return `${yearStr}-${monthStr}-${dayStr}`;
}