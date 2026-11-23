import 'dart:convert';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

import '../models/app_models.dart';

enum ReportFileFormat {
  pdf('PDF', 'pdf'),
  xml('XML', 'xml');

  const ReportFileFormat(this.label, this.extension);

  final String label;
  final String extension;
}

class ReportExportService {
  const ReportExportService();

  String fileName({
    required String period,
    required DateTime generatedAt,
    required ReportFileFormat format,
  }) {
    final suffix = period == 'yearly'
        ? DateFormat('yyyy').format(generatedAt)
        : DateFormat('yyyy-MM').format(generatedAt);
    final periodName = _periodLabel(period);
    return 'QuickParking-$periodName-$suffix.${format.extension}';
  }

  Future<Uint8List> buildPdf({
    required String period,
    required DateTime generatedAt,
    required List<Booking> bookings,
    required List<PaymentRecord> payments,
  }) async {
    final document = pw.Document(
      title: 'QuickParking ${_periodLabel(period)} Report',
      author: 'QuickParking',
    );
    final revenue = _totalRevenue(payments);
    final servicedBookings = _servicedBookings(bookings);
    final paymentMethods = _paymentMethodsByBooking(payments);

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'QUICKPARKING',
              style: pw.TextStyle(
                color: PdfColors.teal700,
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.Text('${_periodLabel(period)} report'),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 12),
          pw.Text(
            'Parking ${_periodLabel(period)} Report',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text('Generated: ${_dateTime(generatedAt)}'),
          pw.SizedBox(height: 18),
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.teal50,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _summaryItem('Total bookings', '${bookings.length}'),
                _summaryItem('Total revenue', _currency(revenue)),
                _summaryItem('Serviced bookings', '$servicedBookings'),
              ],
            ),
          ),
          pw.SizedBox(height: 22),
          pw.Text(
            'Booking details',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),
          if (bookings.isEmpty)
            pw.Text('No bookings found for this report period.')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Booking ID',
                'Location',
                'Slot',
                'Vehicle',
                'Start time',
                'Hours',
                'Status',
                'Payment',
                'Amount',
              ],
              data: bookings
                  .map(
                    (booking) => [
                      booking.bookingCode,
                      booking.locationName,
                      booking.slotNumber,
                      booking.vehicleNumber,
                      _dateTime(booking.startTime),
                      '${booking.durationHours}',
                      booking.status,
                      paymentMethods[booking.id] ?? booking.paymentStatus,
                      _currency(booking.amount),
                    ],
                  )
                  .toList(),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.teal700,
              ),
              headerStyle: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 8,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellPadding: const pw.EdgeInsets.all(5),
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
        ],
      ),
    );

    return document.save();
  }

  Uint8List buildXml({
    required String period,
    required DateTime generatedAt,
    required List<Booking> bookings,
    required List<PaymentRecord> payments,
  }) {
    final builder = XmlBuilder();
    final paymentMethods = _paymentMethodsByBooking(payments);
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'quickParkingReport',
      attributes: {
        'period': period,
        'generatedAt': generatedAt.toIso8601String(),
      },
      nest: () {
        builder.element(
          'summary',
          nest: () {
            builder.element('totalBookings', nest: bookings.length);
            builder.element('totalRevenue', nest: _totalRevenue(payments));
            builder.element(
              'servicedBookings',
              nest: _servicedBookings(bookings),
            );
          },
        );
        builder.element(
          'bookings',
          nest: () {
            for (final booking in bookings) {
              builder.element(
                'booking',
                attributes: {'id': booking.id, 'code': booking.bookingCode},
                nest: () {
                  builder.element('location', nest: booking.locationName);
                  builder.element('slot', nest: booking.slotNumber);
                  builder.element('vehicleNumber', nest: booking.vehicleNumber);
                  builder.element(
                    'startTime',
                    nest: booking.startTime.toIso8601String(),
                  );
                  builder.element(
                    'endTime',
                    nest: booking.endTime.toIso8601String(),
                  );
                  builder.element('durationHours', nest: booking.durationHours);
                  builder.element('status', nest: booking.status);
                  builder.element('amount', nest: booking.amount);
                  builder.element('paymentStatus', nest: booking.paymentStatus);
                  builder.element(
                    'paymentMethod',
                    nest: paymentMethods[booking.id] ?? 'Not recorded',
                  );
                },
              );
            }
          },
        );
      },
    );

    final xml = builder.buildDocument().toXmlString(pretty: true, indent: '  ');
    return Uint8List.fromList(utf8.encode(xml));
  }

  static pw.Widget _summaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 4),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static Map<String, String> _paymentMethodsByBooking(
    List<PaymentRecord> payments,
  ) {
    return {
      for (final payment in payments)
        payment.bookingId: '${payment.method} (${payment.status})',
    };
  }

  static double _totalRevenue(List<PaymentRecord> payments) {
    return payments
        .where((payment) => payment.status == 'success')
        .fold(0, (sum, payment) => sum + payment.amount);
  }

  static int _servicedBookings(List<Booking> bookings) {
    return bookings
        .where(
          (booking) =>
              booking.status == 'active' || booking.status == 'completed',
        )
        .length;
  }

  static String _periodLabel(String period) {
    return period == 'yearly' ? 'Yearly' : 'Monthly';
  }

  static String _currency(double value) => 'Rs ${value.toStringAsFixed(2)}';

  static String _dateTime(DateTime value) {
    return DateFormat('dd MMM yyyy, hh:mm a').format(value.toLocal());
  }
}
