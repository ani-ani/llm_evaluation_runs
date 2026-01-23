module clock_fixer (
    input wire [1:0] format,
    input wire [31:0] display_time,
    output reg [31:0] corrected_time
);

    // Extract digits from display_time (assumed format HHMM packed as 4 bytes)
    // display_time[31:24] -> H tens, H ones
    // display_time[15:8]  -> M tens, M ones
    wire [3:0] h_tens_in;
    wire [3:0] h_ones_in;
    wire [3:0] m_tens_in;
    wire [3:0] m_ones_in;

    assign h_tens_in = display_time[31:28];
    assign h_ones_in = display_time[27:24];
    assign m_tens_in = display_time[15:12];
    assign m_ones_in = display_time[11:8];

    // Intermediate registers for combinational logic
    reg [3:0] best_h_tens, best_h_ones;
    reg [3:0] best_m_tens, best_m_ones;
    reg [7:0] min_diff;
    reg [7:0] current_diff;
    
    // Helper to convert BCD to binary index for iteration
    integer hour_val, min_val;
    integer h_t, h_o, m_t, m_o;
    
    // ASCII conversion wires
    wire [7:0] h_tens_ascii = {4'h3, best_h_tens};
    wire [7:0] h_ones_ascii = {4'h3, best_h_ones};
    wire [7:0] m_tens_ascii = {4'h3, best_m_tens};
    wire [7:0] m_ones_ascii = {4'h3, best_ones};

    always @(*) begin
        min_diff = 8'hFF;
        best_h_tens = 4'h0;
        best_h_ones = 4'h0;
        best_m_tens = 4'h0;
        best_m_ones = 4'h0;

        if (format == 2'b01) begin // 12-hour format
            // Iterate hours 1-12
            for (hour_val = 1; hour_val <= 12; hour_val = hour_val + 1) begin
                // Convert binary hour to BCD
                if (hour_val < 10) begin
                    h_t = 0;
                    h_o = hour_val;
                end else begin
                    h_t = 1;
                    h_o = hour_val - 10;
                end

                // Iterate minutes 0-59
                for (min_val = 0; min_val < 60; min_val = min_val + 1) begin
                    // Convert binary min to BCD
                    m_t = min_val / 10;
                    m_o = min_val % 10;

                    // Calculate Hamming distance
                    current_diff = 0;
                    if (h_t[3:0] != h_tens_in) current_diff = current_diff + 1;
                    if (h_o[3:0] != h_ones_in) current_diff = current_diff + 1;
                    if (m_t[3:0] != m_tens_in) current_diff = current_diff + 1;
                    if (m_o[3:0] != m_ones_in) current_diff = current_diff + 1;

                    if (current_diff < min_diff) begin
                        min_diff = current_diff;
                        best_h_tens = h_t[3:0];
                        best_h_ones = h_o[3:0];
                        best_m_tens = m_t[3:0];
                        best_m_ones = m_o[3:0];
                    end
                    if (min_diff == 0) break;
                end
                if (min_diff == 0) break;
            end
        end else if (format == 2'b10) begin // 24-hour format
            // Iterate hours 0-23
            for (hour_val = 0; hour_val < 24; hour_val = hour_val + 1) begin
                // Convert binary hour to BCD
                if (hour_val < 10) begin
                    h_t = 0;
                    h_o = hour_val;
                end else begin
                    h_t = 1;
                    h_o = hour_val - 10;
                end

                // Iterate minutes 0-59
                for (min_val = 0; min_val < 60; min_val = min_val + 1) begin
                    // Convert binary min to BCD
                    m_t = min_val / 10;
                    m_o = min_val % 10;

                    // Calculate Hamming distance
                    current_diff = 0;
                    if (h_t[3:0] != h_tens_in) current_diff = current_diff + 1;
                    if (h_o[3:0] != h_ones_in) current_diff = current_diff + 1;
                    if (m_t[3:0] != m_tens_in) current_diff = current_diff + 1;
                    if (m_o[3:0] != m_ones_in) current_diff = current_diff + 1;

                    if (current_diff < min_diff) begin
                        min_diff = current_diff;
                        best_h_tens = h_t[3:0];
                        best_h_ones = h_o[3:0];
                        best_m_tens = m_t[3:0];
                        best_m_ones = m_o[3:0];
                    end
                    if (min_diff == 0) break;
                end
                if (min_diff == 0) break;
            end
        end
    end

    // Construct output (ASCII)
    assign corrected_time = {
        {4'h3, best_h_tens},
        {4'h3, best_h_ones},
        8'h00, // Placeholder for colon or ignored byte
        {4'h3, best_m_tens},
        {4'h3, best_m_ones}
    };

endmodule