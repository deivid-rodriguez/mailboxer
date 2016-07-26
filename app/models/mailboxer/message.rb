class Mailboxer::Message < Mailboxer::Notification
  attr_accessible :attachment if Mailboxer.protected_attributes?
  self.table_name = :mailboxer_notifications

  belongs_to :conversation, :autosave => true
  validates_presence_of :sender

  validate :at_least_one_recipient

  class_attribute :on_deliver_callback
  protected :on_deliver_callback
  scope :conversation, lambda { |conversation|
    where(:conversation_id => conversation.id)
  }

  mount_uploader :attachment, Mailboxer::AttachmentUploader

  class << self
    #Sets the on deliver callback method.
    def on_deliver(callback_method)
      self.on_deliver_callback = callback_method
    end
  end

  #Delivers a Message. USE NOT RECOMENDED.
  #Use Mailboxer::Models::Message.send_message instead.
  def deliver(reply = false, should_clean = true)
    self.clean if should_clean

    #Receiver receipts
    receiver_receipts = recipients.map do |r|
      receipts.build(receiver: r, mailbox_type: 'inbox', is_read: false)
    end

    #Sender receipt
    sender_receipt =
      receipts.build(receiver: sender, mailbox_type: 'sentbox', is_read: true)

    if valid?
      Mailboxer::MailDispatcher.new(self, receiver_receipts).call
      save!

      conversation.touch if reply

      self.recipients = nil

      on_deliver_callback.call(self) if on_deliver_callback
    end
    sender_receipt
  end

  private

  def at_least_one_recipient
    return true unless recipients.count == 0 ||
                       (recipients.count == 1 && recipients.first == sender)

    errors.add(:recipients, 'needs at least one recipient')
    false
  end
end
