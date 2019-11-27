// Return original string in case no translate function is provided
function returnOriginal (string) {
  return string
}

// TODO: Bring default role in here. Later might go to the roles API
/**
   * Returns object with collaborator roles
   * @param {boolean} isFolder  Defines if the item is folder
   * @param {function} $gettext  Function to translate neccessary strings
   * @returns {object}  Collaborator roles
   */
export default ({ isFolder = false, $gettext = returnOriginal }) => {
  // TODO: read from roles API instead
  const roles = {
    viewer: {
      name: 'viewer',
      label: $gettext('Viewer'),
      description: $gettext('Recipients can view and download contents.'),
      permissions: ['read']
    }
  }

  if (isFolder) {
    roles.contributor = {
      name: 'contributor',
      label: $gettext('Contributor'),
      description: $gettext('Recipients can view, download and upload contents.'),
      permissions: ['read', 'create']
    }
    roles.editor = {
      name: 'editor',
      label: $gettext('Editor'),
      description: $gettext('Recipients can view, download, edit, delete and upload contents.'),
      permissions: ['read', 'update', 'create', 'delete']
    }
    roles.uploader = {
      name: 'uploader',
      label: $gettext('Uploader'),
      description: $gettext('Receive files from multiple recipients without revealing the contents of the folder.'),
      permissions: ['create']
    }
  }

  return roles
}
