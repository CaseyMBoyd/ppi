import LightningDatatable from "lightning/datatable";
import picklistView from "./picklistView.html";
import picklistEdit from "./picklistEdit.html";
import statusIndicator from "./statusIndicator.html";
import filePreview from "./filePreview.html";

export default class WebdocsFileSelectorPicklist extends LightningDatatable {
  static customTypes = {
    customPicklist: {
      template: picklistView,
      editTemplate: picklistEdit,
      standardCellLayout: true,
      typeAttributes: ["options", "value", "label", "placeholder", "recordId"]
    },
    statusIndicator: {
      template: statusIndicator,
      standardCellLayout: true,
      typeAttributes: ["success", "warning", "error"]
    },
    filePreview: {
      template: filePreview,
      standardCellLayout: true,
      typeAttributes: ["recordId", "fileName"]
    }
  };
}