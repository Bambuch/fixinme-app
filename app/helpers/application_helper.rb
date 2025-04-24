module ApplicationHelper
  # TODO: replace legacy content_tag with tag.tagname
  class LabelledFormBuilder < ActionView::Helpers::FormBuilder
    (field_helpers - [:label]).each do |selector|
      class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
        def #{selector}(method, options = {})
          labelled_row_for(method, options) { super }
        end
      RUBY_EVAL
    end

    def select(method, choices = nil, options = {}, html_options = {})
      labelled_row_for(method, options) { super }
    end

    def submit(value, options = {})
      @template.content_tag :tr do
        @template.content_tag :td, super, colspan: 2
      end
    end

    def form_for(&block)
      @template.content_tag(:table, class: "centered") { yield(self) } +
      @template.content_tag(:div, @object&.errors.full_messages.join(@template.tag(:br)))
    end

    private

    def labelled_row_for(method, options)
      @template.content_tag :tr do
        @template.content_tag(:td, label_for(method, options), class: "unwrappable") +
        @template.content_tag(:td, options.delete(:readonly) ? @object.public_send(method) : yield,
          @object&.errors[method].present? ?
            {class: "error", data: {content: @object&.errors.delete(method).join(" and ")}} :
            {})
      end
    end

    def label_for(method, options = {})
      return "" if options[:label] == false
      text = options.delete(:label) || @object.class.human_attribute_name(method).capitalize

      classes = @template.class_names(required: options[:required],
                                      error: @object&.errors[method].present?)

      label(method, "#{text}:", class: classes) +
        (options[:hint] ? @template.tag(:br) + @template.content_tag(:em, options.delete(:hint)) : "")
    end
  end

  def labelled_form_for(record, options = {}, &block)
    options = options.deep_merge(builder: LabelledFormBuilder, data: {turbo: false})
    form_for(record, **options) { |f| f.form_for(&block) }
  end

  class TabularFormBuilder < ActionView::Helpers::FormBuilder
    def initialize(...)
      super(...)
      @default_options.merge!(@options.slice(:form))
    end

    [:text_field, :password_field, :text_area].each do |selector|
      class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
        def #{selector}(method, options = {})
          options[:maxlength] ||= object.class.type_for_attribute(method)&.limit
          if object.errors.include?(method)
            options[:pattern] = except_pattern(object.public_send(method), options[:pattern])
          end
          super
        end
      RUBY_EVAL
    end

    def number_field(method, options = {})
      value = object.public_send(method)
      if value.is_a?(BigDecimal)
        options[:value] = value.to_s("F")
        type = object.class.type_for_attribute(method)
        options[:step] ||= BigDecimal(10).power(-type.scale)
        options[:max] ||= BigDecimal(10).power(type.precision - type.scale) - options[:step]
        options[:min] = options[:min] == :step ? options[:step] : options[:min] || -options[:max]
      end
      super
    end

    def button(value = nil, options = {}, &block)
      options.merge!(@options.slice(:form))
      super
    end

    private

    def submit_default_value
      svg_name = object ? (object.persisted? ? 'update' : 'plus-circle-outline') : ''
      @template.svg_tag("pictograms/#{svg_name}") + super
    end

    def except_pattern(value, pattern = nil)
      "(?!^#{Regexp.escape(value.to_s)}$)" + (pattern || ".*")
    end
  end

  def tabular_fields_for(record_name, record_object = nil, options = {}, &block)
    record_object, options = nil, record_object if record_object.is_a?(Hash)
    options.merge!(builder: TabularFormBuilder, skip_default_ids: true)
    render_errors(record_object || record_name)
    fields_for(record_name, record_object, **options, &block)
  end

  def tabular_form_with(**options, &block)
    options = options.deep_merge(builder: TabularFormBuilder, html: {autocomplete: 'off'})
    form_with(**options, &block)
  end

  def svg_tag(source, options = {})
    content_tag :svg, options do
      tag.use href: "#{image_path(source)}.svg#icon"
    end
  end

  def navigation_menu
    menu_tabs = [
      ['measurements', 'scale-bathroom', :restricted],
      ['quantities', 'axis-arrow', :restricted, 'right'],
      ['units', 'weight-gram', :restricted],
      ['users', 'account-multiple-outline', :admin],
    ]

    menu_tabs.map do |name, image, status, css_class|
      if current_user.at_least(status)
        link_to svg_tag("pictograms/#{image}") + t("#{name}.navigation"),
          {controller: "/#{name}", action: "index"},
          class: class_names('tab', css_class, active: name == current_tab)
      end
    end.join.html_safe
  end

  def image_button_to(name, image = nil, options = nil, html_options = {})
    name, html_options = link_or_button_options(:button, name, image, html_options)
    button_to name, options, html_options
  end

  def image_button_tag(name, image = nil, html_options = {})
    name, html_options = link_or_button_options(:button, name, image, html_options)
    button_tag name, html_options
  end

  def image_link_to(name, image = nil, options = nil, html_options = {})
    name, html_options = link_or_button_options(:link, name, image, html_options)
    link_to name, options, html_options
  end

  DISABLED_ATTRIBUTES = {disabled: true, aria: {disabled: true}, tabindex: -1}

  def image_button_to_if(condition, name, image = nil, options = nil, html_options = {})
    name, html_options = link_or_button_options(:button, name, image, html_options)
    html_options = html_options.deep_merge DISABLED_ATTRIBUTES unless condition
    button_to name, options, html_options
  end

  def image_link_to_unless_current(name, image = nil, options = nil, html_options = {})
    name, html_options = link_or_button_options(:link, name, image, html_options)
    html_options = html_options.deep_merge DISABLED_ATTRIBUTES if current_page?(options)
    link_to name, options, html_options
  end

  def render_errors(records)
    flash[:alert] ||= []
    Array(records).each { |record| flash[:alert] += record.errors.full_messages }
  end

  def render_flash_messages
    flash.map do |entry, messages|
      Array(messages).map do |message|
        tag.div class: "flash #{entry}" do
          tag.div(sanitize(message)) + tag.button(sanitize("&times;"), tabindex: -1,
                                                  onclick: "this.parentElement.remove();")
        end
      end
    end.join.html_safe
  end

  def render_no_items
    tag.tr id: :no_items do
      tag.td t("#{controller_path.tr('/', '.')}.no_items"), colspan: 10, class: 'hint'
    end
  end

  def render_turbo_stream(partial, locals = {})
    "Turbo.renderStreamMessage('#{j(render partial: partial, locals: locals)}'); return false;"
  end

  private

  def link_or_button_options(type, name, image = nil, html_options)
    name = (image ? svg_tag("pictograms/#{image}") : '') + name.to_s

    html_options[:class] = class_names(
      html_options[:class],
      'button',
      dangerous: html_options[:method] == :delete
    )

    if html_options[:onclick]&.is_a? Hash
      html_options[:onclick] = "return confirm('\#{html_options[:onclick][:confirm]}');"
    end

    if type == :link && !(html_options[:onclick] || html_options.dig(:data, :turbo_stream))
      name += '...'
    end

    [name, html_options]
  end
end
