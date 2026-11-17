import {test,expect} from 'bun:test';
import {nextIndex} from '../app/Navigation.mjs';
test('setas respeitam as colunas visíveis',()=>{expect(nextIndex(1,'down',30,9)).toBe(10);expect(nextIndex(10,'up',30,9)).toBe(1);expect(nextIndex(10,'left',30,9)).toBe(9);expect(nextIndex(9,'right',30,9)).toBe(10);expect(nextIndex(1,'down',30,5)).toBe(6);});
test('bordas, linha incompleta e lista vazia',()=>{expect(nextIndex(0,'left',12,9)).toBe(0);expect(nextIndex(11,'right',12,9)).toBe(11);expect(nextIndex(7,'down',12,9)).toBe(11);expect(nextIndex(10,'down',12,9)).toBe(10);expect(nextIndex(3,'up',12,9)).toBe(3);expect(nextIndex(0,'down',0,9)).toBe(-1);});
test('Home, End e paginação mantêm seleção válida',()=>{expect(nextIndex(12,'first',40,9)).toBe(0);expect(nextIndex(12,'last',40,9)).toBe(39);expect(nextIndex(0,'pageDown',40,9,3)).toBe(27);expect(nextIndex(27,'pageDown',40,9,3)).toBe(39);expect(nextIndex(12,'pageUp',40,9,3)).toBe(0);});
