import React, { useRef, useEffect } from 'react';
import Image from './image';
import useI18n from '../hooks/use-i18n';

function SubmissionPending() {
  const { t } = useI18n();
  const headingRef = useRef(/** @type {?HTMLHeadingElement} */ (null));
  useEffect(() => {
    headingRef.current?.focus();
  }, []);

  return (
    <div>
      <Image assetPath="id-card.svg" alt="" width="216" height="116" />
      <h2 ref={headingRef} tabIndex={-1}>
        {t('doc_auth.headings.interstitial')}
      </h2>
      <p>{t('doc_auth.info.interstitial_eta')}</p>
      <p>{t('doc_auth.info.interstitial_thanks')}</p>
    </div>
  );
}

export default SubmissionPending;