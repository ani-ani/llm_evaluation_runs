module list_append (
    input [7:0] list_data [0:7],
    input [2:0] list_len,
    input [7:0] tuple_data [0:7],
    input [2:0] tuple_len,
    output logic [7:0] result [0:7],
    output logic [2:0] result_len
);

    integer i;
    logic [3:0] total_len;
    logic [3:0] avail_list;
    logic [2:0] eff_list_len;

    always_comb begin
        // Calculate total potential length
        total_len = {1'b0, tuple_len} + {1'b0, list_len};
        
        // Cap result length at 8
        if (total_len > 8)
            result_len = 3'd8;
        else
            result_len = total_len[2:0];
            
        // Determine effective list length (how much fits)
        // If tuple_len + list_len > 8, truncate list to fit in result
        if ({1'b0, tuple_len} + {1'b0, list_len} > 8) begin
            avail_list = 8 - {1'b0, tuple_len};
            eff_list_len = avail_list[2:0];
        end else begin
            eff_list_len = list_len;
        end
        
        // Fill tuple portion
        for (i = 0; i < 8; i++) begin
            if (i < tuple_len)
                result[i] = tuple_data[i];
            else
                result[i] = 8'hxx; // Don't care for unused entries
        end
        
        // Fill list portion
        for (i = 0; i < 8; i++) begin
            if (i >= tuple_len && i < tuple_len + eff_list_len)
                result[i] = list_data[i - tuple_len];
        end
    end

endmodule