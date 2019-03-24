import { Controller } from 'stimulus'
import 'select2/dist/js/select2.full'

export default class extends Controller {
  connect() {
    const options = {
      theme: 'bootstrap',
      containerCssClass: ':all:',
      width: '100%',
      minimumResultsForSearch: 10
    }

    const $element = $(this.element)

    $element.select2(options);

    $(document).one('turbolinks:before-cache', this.teardown.bind(this))
  }

  teardown() {
    const $element = $(this.element)
    if ($element.next().is('.select2')) $element.select2('destroy')
  }
}
