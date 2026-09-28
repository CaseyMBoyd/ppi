function normalizeToken(value) {
  return typeof value === "string" ? value.trim() : "";
}

function addUniqueValue(values, existingValues, value) {
  const trimmedValue = normalizeToken(value);

  if (!trimmedValue) {
    return;
  }

  const normalizedValue = trimmedValue.toLowerCase();

  if (existingValues.has(normalizedValue)) {
    return;
  }

  existingValues.add(normalizedValue);
  values.push(trimmedValue);
}

export function tokenizeSemicolonValue(rawValue) {
  const existingValues = new Set();
  const values = [];

  normalizeToken(rawValue)
    .split(";")
    .forEach((value) => {
      addUniqueValue(values, existingValues, value);
    });

  return values;
}

export function normalizeValueList(rawValue) {
  const existingValues = new Set();
  const values = [];

  if (Array.isArray(rawValue)) {
    rawValue.forEach((value) => {
      tokenizeSemicolonValue(value).forEach((token) => {
        addUniqueValue(values, existingValues, token);
      });
    });
    return values;
  }

  tokenizeSemicolonValue(rawValue).forEach((value) => {
    addUniqueValue(values, existingValues, value);
  });

  return values;
}

export function normalizeSingleSelection(rawValue) {
  const [value] = normalizeValueList(rawValue);
  return value || "";
}

export function buildSourceSnapshot(
  orderNumbers = [],
  quoteNumbers = [],
  poNumbers = []
) {
  return {
    orderNumbers: normalizeValueList(orderNumbers),
    quoteNumbers: normalizeValueList(quoteNumbers),
    poNumbers: normalizeValueList(poNumbers)
  };
}

function hasOrderedValueMatch(leftValues = [], rightValues = []) {
  if (leftValues.length !== rightValues.length) {
    return false;
  }

  return leftValues.every(
    (leftValue, index) =>
      leftValue.toLowerCase() === (rightValues[index] || "").toLowerCase()
  );
}

export function parseStoredRelationships(rawValue) {
  const relationshipMap = new Map();
  const storedOrderNumbers = [];
  const trimmedValue = normalizeToken(rawValue);
  let sourceSnapshot = {
    ...buildSourceSnapshot(),
    hasSnapshot: false
  };

  if (!trimmedValue) {
    return {
      hasInvalidFormat: false,
      relationshipMap,
      storedOrderNumbers,
      sourceSnapshot
    };
  }

  try {
    const parsedValue = JSON.parse(trimmedValue);

    if (!Array.isArray(parsedValue)) {
      throw new Error("Stored relationships must be an array.");
    }

    parsedValue.forEach((item) => {
      if (item && typeof item === "object" && !sourceSnapshot.hasSnapshot) {
        const hasSourceSnapshot =
          "sourceOrderNumbers" in item ||
          "sourceQuoteNumbers" in item ||
          "sourcePoNumbers" in item;

        if (hasSourceSnapshot) {
          sourceSnapshot = {
            ...buildSourceSnapshot(
              item.sourceOrderNumbers,
              item.sourceQuoteNumbers,
              item.sourcePoNumbers
            ),
            hasSnapshot: true
          };
        }
      }

      const orderNumber =
        item && typeof item === "object"
          ? normalizeToken(item.orderNumber)
          : "";

      if (!orderNumber) {
        return;
      }

      const normalizedOrderNumber = orderNumber.toLowerCase();

      if (!relationshipMap.has(normalizedOrderNumber)) {
        storedOrderNumbers.push(orderNumber);
      }

      relationshipMap.set(normalizedOrderNumber, {
        orderNumber,
        quoteNumbers: normalizeValueList(item.quoteNumbers ?? item.quoteNumber),
        poNumbers: normalizeValueList(item.poNumbers ?? item.poNumber)
      });
    });

    return {
      hasInvalidFormat: false,
      relationshipMap,
      storedOrderNumbers,
      sourceSnapshot
    };
  } catch (error) {
    return {
      hasInvalidFormat: true,
      relationshipMap: new Map(),
      storedOrderNumbers: [],
      sourceSnapshot: {
        ...buildSourceSnapshot(),
        hasSnapshot: false
      }
    };
  }
}

export function buildRelationshipRows(
  orderNumbers,
  quoteNumbers = [],
  poNumbers = [],
  relationshipMap = new Map()
) {
  return orderNumbers.map((orderNumber, index) => {
    const normalizedOrderNumber = orderNumber.toLowerCase();
    const hasStoredRelationship = relationshipMap.has(normalizedOrderNumber);
    const relationship = relationshipMap.get(normalizedOrderNumber) || {};
    const defaultQuoteNumbers =
      orderNumbers.length === 1
        ? normalizeValueList(quoteNumbers)
        : normalizeSingleSelection(quoteNumbers[index])
          ? [normalizeSingleSelection(quoteNumbers[index])]
          : [];
    const defaultPoNumbers =
      orderNumbers.length === 1
        ? normalizeValueList(poNumbers)
        : poNumbers.length === 1
          ? normalizeValueList(poNumbers[0])
          : normalizeSingleSelection(poNumbers[index])
            ? [normalizeSingleSelection(poNumbers[index])]
            : [];

    return {
      key: `${index}-${orderNumber}`,
      orderNumber,
      quoteNumbers: hasStoredRelationship
        ? normalizeValueList(relationship.quoteNumbers)
        : defaultQuoteNumbers,
      poNumbers: hasStoredRelationship
        ? normalizeValueList(relationship.poNumbers)
        : defaultPoNumbers
    };
  });
}

export function serializeRelationships(rows, sourceSnapshot = null) {
  const normalizedSourceSnapshot = sourceSnapshot
    ? buildSourceSnapshot(
        sourceSnapshot.orderNumbers,
        sourceSnapshot.quoteNumbers,
        sourceSnapshot.poNumbers
      )
    : null;

  return JSON.stringify(
    rows.map((row) => ({
      orderNumber: normalizeToken(row.orderNumber),
      quoteNumbers: normalizeValueList(row.quoteNumbers),
      poNumbers: normalizeValueList(row.poNumbers),
      ...(normalizedSourceSnapshot
        ? {
            sourceOrderNumbers: normalizedSourceSnapshot.orderNumbers,
            sourceQuoteNumbers: normalizedSourceSnapshot.quoteNumbers,
            sourcePoNumbers: normalizedSourceSnapshot.poNumbers
          }
        : {})
    }))
  );
}

export function buildSelectableOptions(
  availableValues,
  selectedValues,
  missingLabelSuffix
) {
  const options = [];
  const includedValues = new Set();

  availableValues.forEach((value) => {
    const normalizedValue = value.toLowerCase();

    if (includedValues.has(normalizedValue)) {
      return;
    }

    includedValues.add(normalizedValue);
    options.push({
      label: value,
      value
    });
  });

  normalizeValueList(selectedValues).forEach((value) => {
    const normalizedValue = value.toLowerCase();

    if (includedValues.has(normalizedValue)) {
      return;
    }

    includedValues.add(normalizedValue);
    options.push({
      label: `${value} ${missingLabelSuffix}`,
      value
    });
  });

  return options;
}

export function hasRelationshipDrift(storedOrderNumbers, currentOrderNumbers) {
  return !hasOrderedValueMatch(
    normalizeValueList(storedOrderNumbers),
    normalizeValueList(currentOrderNumbers)
  );
}

export function hasSourceSnapshotDrift(sourceSnapshot, currentSourceSnapshot) {
  if (!sourceSnapshot?.hasSnapshot) {
    return false;
  }

  return (
    hasRelationshipDrift(
      sourceSnapshot.orderNumbers,
      currentSourceSnapshot.orderNumbers
    ) ||
    hasRelationshipDrift(
      sourceSnapshot.quoteNumbers,
      currentSourceSnapshot.quoteNumbers
    ) ||
    hasRelationshipDrift(
      sourceSnapshot.poNumbers,
      currentSourceSnapshot.poNumbers
    )
  );
}

export function requiresUserReview(orderNumbers, quoteNumbers, poNumbers) {
  return (
    orderNumbers.length > 1 && (quoteNumbers.length > 1 || poNumbers.length > 1)
  );
}