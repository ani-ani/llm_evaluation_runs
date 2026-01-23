module clock_fixer (
    input wire [1:0] format,          // 01 for 12-hour, 10 for 24-hour
    input wire [31:0] display_time,    // ASCII string HHMM (4 bytes)
    output reg [31:0] corrected_time   // ASCII string HHMM (4 bytes)
);

    // Internal signals to extract digits from display_time
    wire [3:0] h_tens = display_time[31:28];
    wire [3:0] h_ones = display_time[27:24];
    wire [3:0] m_tens = display_time[19:16];
    wire [3:0] m_ones = display_time[15:12];

    // Combinational logic to find the best valid time
    // Strategy: Iterate through all valid times and calculate Hamming distance
    // Valid ranges:
    // 12-hour: Hours 01-12 (01, 02, ..., 12), Minutes 00-59
    // 24-hour: Hours 00-23 (00, 01, ..., 23), Minutes 00-59

    integer i, j; // Loop variables
    reg [3:0] best_h_tens, best_h_ones;
    reg [3:0] best_m_tens, best_m_ones;
    reg [7:0] min_diff;
    reg [7:0] current_diff;
    reg [3:0] current_h_tens, current_h_ones;
    reg [3:0] current_m_tens, current_m_ones;

    always @(*) begin
        min_diff = 8'hFF; // Initialize to maximum possible difference (4)
        
        // Check all possible valid times
        if (format == 2'b01) begin // 12-hour format
            // Hours: 01 to 12
            for (i = 1; i <= 12; i = i + 1) begin
                current_h_tens = (i < 10) ? 4'h0 : 4'h1;
                current_h_ones = (i < 10) ? i[3:0] : (i - 10)[3:0];
                
                // Minutes: 00 to 59
                for (j = 0; j < 60; j = j + 1) begin
                    current_m_tens = j[5:4];
                    current_m_ones = j[3:0];
                    
                    // Calculate Hamming distance
                    current_diff = 0;
                    if (current_h_tens != h_tens) current_diff = current_diff + 1;
                    if (current_h_ones != h_ones) current_diff = current_diff + 1;
                    if (current_m_tens != m_tens) current_diff = current_diff + 1;
                    if (current_m_ones != m_ones) current_diff = current_diff + 1;
                    
                    if (current_diff < min_diff) begin
                        min_diff = current_diff;
                        best_h_tens = current_h_tens;
                        best_h_ones = current_h_ones;
                        best_m_tens = current_m_tens;
                        best_m_ones = current_m_ones;
                    end
                    // Early exit if perfect match found
                    if (min_diff == 0) break;
                end
                if (min_diff == 0) break;
            end
        end else if (format == 2'b10) begin // 24-hour format
            // Hours: 00 to 23
            for (i = 0; i < 24; i = i + 1) begin
                current_h_tens = i[4:3];
                current_h_ones = i[3:0];
                
                // Minutes: 00 to 59
                for (j = 0; j < 60; j = j + 1) begin
                    current_m_tens = j[5:4];
                    current_m_ones = j[3:0];
                    
                    // Calculate Hamming distance
                    current_diff = 0;
                    if (current_h_tens != h_tens) current_diff = current_diff + 1;
                    if (current_h_ones != h_ones) current_diff = current_diff + 1;
                    if (current_m_tens != m_tens) current_diff = current_diff + 1;
                    if (current_m_ones != m_ones) current_diff = current_diff + 1;
                    
                    if (current_diff < min_diff) begin
                        min_diff = current_diff;
                        best_h_tens = current_h_tens;
                        best_h_ones = current_h_ones;
                        best_m_tens = current_m_tens;
                        best_m_ones = current_m_ones;
                    end
                    if (min_diff == 0) break;
                end
                if (min_diff == 0) break;
            end
        end
    end

    // Construct output string
    // ASCII '0' is 0x30. Digits 0-9 are 0x30 to 0x39.
    // Input is ASCII, so we convert internal digits back to ASCII.
    wire [7:0] h_tens_ascii = {4'h3, best_h_tens};
    wire [7:0] h_ones_ascii = {4'h3, best_h_ones};
    wire [7:0] m_tens_ascii = {4'h3, best_m_tens};
    wire [7:0] m_ones_ascii = {4'h3, best_m_ones};

    // Format: HHMM
    assign corrected_time = {h_tens_ascii, h_ones_ascii, m_tens_ascii, m_ones_ascii};

endmodule