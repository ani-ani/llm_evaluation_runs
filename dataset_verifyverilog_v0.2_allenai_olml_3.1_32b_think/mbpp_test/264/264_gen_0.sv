module dog_age_calculator (
    input [7:0] human_age,
    output [31:0] dog_age
);
assign dog_age = (human_age <= 2) ? ((human_age << 16) * 'h000A8000) >> 16 : (((human_age - 2) << 16) * 'h00040000) >> 16 + 'h00150000;
endmodule