/* eslint-env node */
import { Footer, Layout, Navbar } from 'nextra-theme-docs'
import { Banner, Head } from 'nextra/components'
import { getPageMap } from 'nextra/page-map'
import 'nextra-theme-docs/style.css'

export const metadata = {
  metadataBase: new URL('https://nextra.site'),
  title: {
    template: '%s - Illinois_Roadbuffs Framework'
  },
  description: 'Recycle and Reuse Threads!',
  applicationName: 'Nextra',
  generator: 'Next.js',
  appleWebApp: {
    title: 'Nextra'
  },
  other: {
    'msapplication-TileImage': '/ms-icon-144x144.png',
    'msapplication-TileColor': '#fff'
  },
  twitter: {
    site: 'https://nextra.site'
  }
}

export default async function RootLayout({ children }) {
  const navbar = (
    <Navbar
      logo={
        <div>
          <b>ThreadRecycler</b>{' '}
          <span style={{ opacity: '60%' }}>Recycle and Reuse Threads</span>
        </div>
      }
    
      chatLink="https://discord.gg/sd4XfAqNF9"
    />
  )
  return (
    <html lang="en" dir="ltr" suppressHydrationWarning>
      <Head faviconGlyph="✦" />
      <body>
        <Layout
          banner={<Banner storageKey="Nextra 2">🎉 v0.3.0 has been released! </Banner>}
          navbar={navbar}
          footer={<Footer>MIT License Copyright © {new Date().getFullYear()} Illinois_Roadbuff.</Footer>}
          feedback={{ content: "Question(s)? Give me feedback" }}
          editLink="Edit this page on GitHub"
          docsRepositoryBase="https://github.com/illinois-roadbuff/threadrecycler/blob/main/docs/"
          sidebar={{ defaultMenuCollapseLevel: 1 }}
          pageMap={await getPageMap()}
        >
          {children}
        </Layout>
      </body>
    </html>
  )
}
