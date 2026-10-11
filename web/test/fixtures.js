import { readFileSync } from 'node:fs';
import { makeCatalog } from '../js/catalog.js';

const dir = new URL('../../Packages/FitnessCore/Sources/FitnessCore/Resources/', import.meta.url);
const read = name => JSON.parse(readFileSync(new URL(`${name}.json`, dir), 'utf8'));

export const catalog = makeCatalog({ exercises: read('exercises'), plan: read('plan'), videos: read('videos') });
