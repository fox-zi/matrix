class Notification < ApplicationRecord
  belongs_to :user, optional: true

  validates :user_id, :content, presence: true

  scope :ordered_by_new, -> { order created_at: :desc }

  serialize :properties

  def push
    user.devices.each do |device|
      device_token = device.notification_token
      next if device_token.blank?

      self.title = 'Fourtrive' if title.blank?

      if properties[:translate_message_key]
        message = I18n.t properties[:translate_message_key], locale: device.adapt_locale
      end

      Firebase::Notification.push(device_token, { title: title, body: message || content }, properties)
    end
  end

  class << self
    def push_chat(members, sender, message, object, options = {})
      return unless members.all?

      room = ChatRoom.by_members members
      unless room
        service = Chat::CreateService.new members: members
        service.invoke!
        room = service.room
      end

      msg_service = Chat::MessageService.new(
        room: room,
        sender: room.chat_members.find_by!(membership: sender),
        message: message,
        object: object,
        options: options
      )
      msg_service.invoke!
    end

    def push_slack(message)
      return if Rails.env.test? || Rails.env.development?

      begin
        notifier = Slack::Notifier.new Global.slack.url do
          defaults channel: Global.slack.channel, username: 'job'
        end

        notifier.ping message
      rescue StandardError => e
        Raven.capture_exception(e)
      end
    end

    def requested(ticket, sender)
      unless ticket.after_ticket?
        members = [ticket.photographer, sender]
        push_chat(members, sender, 'bot.created_ticket', {
                    type: :ticket,
                    id: ticket.id,
                    action: 'request',
                    i18n: true
                  },
                  { translate_message_key: 'bot.created_ticket' })
        push_guide_message(ticket.id, sender, ticket.photographer, 'bot.guide_to_wait_approved')
      end
      push_slack("USER:(#{sender.id})#{sender.name}さんが(#{ticket.id})#{ticket.title}の撮影依頼をしました")
    end

    def approved(ticket, sender)
      members = [ticket.clients.first, sender]

      push_chat(members, sender, 'bot.approved_ticket', {
                  type: :ticket,
                  id: ticket.id,
                  action: 'accept',
                  message: ticket.meeting_memo,
                  i18n: true
                },
                { translate_message_key: 'bot.approved_ticket' })

      push_guide_message(ticket.id, ticket.clients.first, sender, 'bot.guide_to_purchase_ticket')
      ticket.clients.each do |user|
        UserMailer.approved(user.email).deliver if user.email.present?
      end

      push_slack("CAM:(#{sender.id})#{sender.name}さんが(#{ticket.id})#{ticket.title}の撮影依頼承認をしました")
    end

    def rejected(ticket, sender)
      members = [ticket.clients.first, sender]

      push_chat(members, sender, 'bot.rejected_ticket', {
                  type: :ticket,
                  id: ticket.id,
                  action: 'reject',
                  message: ticket.reject_comment,
                  i18n: true
                },
                { translate_message_key: 'bot.rejected_ticket' })

      push_slack("CAM:(#{sender.id})#{sender.name}さんが(#{ticket.id})#{ticket.title}の撮影依頼を拒否しました")
    end

    def canceled(ticket, sender, message)
      members = [ticket.photographer, sender]

      push_chat(members, sender, 'bot.canceled_ticket', {
                  type: :ticket,
                  id: ticket.id,
                  action: 'cancel',
                  message: message,
                  i18n: true
                },
                { translate_message_key: 'bot.canceled_ticket' })
      push_slack("USER:(#{sender.id})#{sender.name}さんが(#{ticket.id})#{ticket.title}の撮影依頼をキャンセルしました")
    end

    def contracted(ticket, sender, sale)
      members = [ticket.photographer, sender]

      push_chat(members, sender, 'bot.contracted_ticket', {
                  type: :ticket,
                  id: ticket.id,
                  action: 'contract',
                  image: ticket.cover_url,
                  title: ticket.title,
                  i18n: true
                },
                { translate_message_key: 'bot.contracted_ticket' })

      push_guide_message(ticket.id, sender, ticket.photographer, 'bot.guide_to_wait_shooting')

      push_slack("USER:(#{sender.id})#{sender.name}さんが(#{ticket.id})#{ticket.title}のチケットを購入しました[購入金額: #{sale.total_amount.to_s(:currency, locale: :ja)}]")
    end

    def guilty_settled(ticket, sender)
      PhotographerMailer.guilty_settled(ticket, sender.user.email).deliver
    end

    def settled(ticket, sender)
      PhotographerMailer.settled(ticket, sender.user.email).deliver
    end

    def uploaded(ticket, sender)
      members = [ticket.clients.first, sender]

      push_chat(members, sender, 'bot.uploaded_photo', {
                  type: :ticket,
                  id: ticket.id,
                  action: 'uploaded',
                  i18n: true
                },
                { translate_message_key: 'bot.uploaded_photo' })

      push_guide_message(ticket.id, ticket.clients.first, sender, 'bot.guide_to_purchase_photo')

      push_slack("CAM:(#{sender.id})#{sender.name}さんが(#{ticket.id})#{ticket.title}に写真をアップロードしました")
    end

    def purchased(ticket, sender, sale)
      members = [ticket.photographer, sender]

      push_chat(members, sender, 'bot.purchased_photo', {
                  type: :ticket,
                  id: ticket.id,
                  action: 'purchased',
                  i18n: true
                },
                { translate_message_key: 'bot.purchased_photo' })

      push_slack("USER:(#{sender.id})#{sender.name}さんが(#{ticket.id})#{ticket.title}の写真を購入しました[購入金額: #{sale.total_amount.to_s(:currency, locale: :ja)}]")
    end

    def replace_photographer(ticket, from, to)
      push_chat([ticket.clients.first, from], from, 'bot.replace_photographer_from', {
                  type: :ticket,
                  id: ticket.id,
                  action: 'replace_photographer',
                  i18n: true
                },
                { translate_message_key: 'bot.replace_photographer_from' })
      push_chat([ticket.clients.first, to], to, 'bot.replace_photographer_to', {
                  type: :ticket,
                  id: ticket.id,
                  action: 'replace_photographer',
                  image: ticket.cover_url,
                  title: ticket.title,
                  i18n: true
                },
                { translate_message_key: 'bot.replace_photographer_to' })
    end

    def new_message(room, sender, message, options = {})
      room.chat_members.includes(:membership).where.not(id: sender.id).all.find_each do |member|
        user = member.membership
        if user.is_a? Photographer
          user = user.user
          new_message_to_photographer(user, room, sender)
        end
        notification = new(user: user)
        notification.title = sender.membership.name
        notification.content = message
        notification.properties = { role: member.membership_type.downcase, type: 'message', room_id: room.id, translate_message_key: options[:translate_message_key] }
        notification.push
      end
    end

    def new_contact(contact)
      push_slack("#{contact.name}さんからお問い合わせがあります\n#{contact.message}")
    end

    def new_message_to_photographer(user, room, sender)
      UserMailer.new_message(user, room, sender).deliver if user.email.present?
    end

    private

    def push_guide_message(id, receiver, sender, guide)
      members = [receiver, sender]
      push_chat(members, sender, guide, {
                  type: :ticket,
                  id: id,
                  i18n: true
                },
                { translate_message_key: guide })
    end
  end
end
